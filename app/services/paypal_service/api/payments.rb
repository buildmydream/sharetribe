module PaypalService::API

  class Payments
    # Injects a configured instance of the merchant client as paypal_merchant
    include PaypalService::MerchantInjector

    MerchantData = PaypalService::DataTypes::Merchant
    TokenStore = PaypalService::Store::Token

    ## POST /payments/request
    def request(community_id, create_payment)
      with_account(
        community_id, create_payment[:merchant_id]
      ) do |m_acc|

        with_success(MerchantData.create_set_express_checkout_order(
          create_payment.merge({ receiver_username: m_acc[:email] })
        )) do |response|
          TokenStore.create(
            community_id,
            response[:token],
            create_payment[:transaction_id],
            m_acc[:person_id])

          Result::Success.new(
            DataTypes.create_payment_request({
                transaction_id: create_payment[:transaction_id],
                token: response[:token],
                redirect_url: response[:redirect_url]}))
        end
      end
    end

    ## POST /payments/request/cancel?token=EC-7XU83376C70426719
    def request_cancel(community_id, token)
      TokenStore.delete(community_id, token)
      Result::Success.new
    end

    ## POST /payments/create?token=EC-7XU83376C70426719
    def create(community_id, token)
      with_token(community_id, token) do |token|
        with_account(community_id, token[:merchant_id]) do |m_acc|
          with_success(MerchantData.create_get_express_checkout_details(
            { receiver_username: m_acc[:email], token: token[:token] }
          )) do |ec_details|

            # Validate that the buyer accepted and we have a payer_id now
            if (ec_details[:payer_id].nil?)
              return Result::Error.new("Payment has not been accepted by the buyer.")
            end

            with_success(MerchantData.create_do_express_checkout_payment(
              {
                receiver_username: m_acc[:email],
                token: token[:token],
                payer_id: ec_details[:payer_id],
                order_total: ec_details[:order_total]
              }
            )) do |payment_res|
              # Save payment
              payment = PaypalService::PaypalPayment::Command.create(
                community_id,
                token[:transaction_id],
                ec_details.merge(payment_res))

              # Delete the token, we have now completed the payment request
              TokenStore.delete(community_id, token[:token])

              # Return as payment entity
              Result::Success.new(DataTypes.create_payment(payment.merge({ merchant_id: m_acc[:person_id] })))
            end
          end
        end
      end
    end

    ## POST /payments/:community_id/:transaction_id/authorize
    def authorize(community_id, transaction_id, info)
      with_payment(community_id, transaction_id) do |payment, m_acc|
        with_success(MerchantData.create_do_authorization({
          receiver_username: m_acc[:email],
          order_id: payment[:order_id],
          authorization_total: info[:authorization_total]
            })) do |auth_res|

          # Save authorization data to payment
          payment = PaypalService::PaypalPayment::Command.update(
            community_id,
            transaction_id,
            auth_res)

          # Return as payment entity
          Result::Success.new(DataTypes.create_payment(payment.merge({ merchant_id: m_acc[:person_id] })))
        end
      end
    end

    ## POST /payments/:community_id/:transaction_id/full_capture
    def full_capture(community_id, transaction_id, info)
      with_payment(community_id, transaction_id) do |payment, m_acc|
        with_success(MerchantData.create_do_full_capture({
          receiver_username: m_acc[:email],
          authorization_id: payment[:authorization_id],
          payment_total: info[:payment_total]
        })) do |payment_res|

          # Save payment data to payment
          payment = PaypalService::PaypalPayment::Command.update(
            community_id,
            transaction_id,
            payment_res
          )

          # Return as payment entity
          Result::Success.new(DataTypes.create_payment(payment.merge({ merchant_id: m_acc[:person_id] })))
        end
      end
    end

    ## GET /payments/:community_id/:transaction_id
    def get_payment(community_id, transaction_id)
      with_payment(community_id, transaction_id) do |payment, m_acc|
        Result::Success.new(DataTypes.create_payment(payment.merge({ merchant_id: m_acc[:person_id] })))
      end
    end

    ## POST /payments/:community_id/:transaction_id/void
    def void(community_id, transaction_id, info)
      with_payment(community_id, transaction_id) do |payment, m_acc|
        with_success(MerchantData.create_do_void({
          receiver_username: m_acc[:email],
          # Always void the order, it automatically voids any authorization connected to the payment
          transaction_id: payment[:order_id],
          note: info[:note]
        })) do |void_res|
          with_success(MerchantData.create_get_transaction_details({
            receiver_username: m_acc[:email],
            transaction_id: payment[:order_id],
          })) do |payment_res|
            payment = PaypalService::PaypalPayment::Command.update(
              community_id,
              transaction_id,
              payment_res)

            # Return as payment entity
            Result::Success.new(DataTypes.create_payment(payment.merge({ merchant_id: m_acc[:person_id] })))
          end
        end
      end
    end

    ## POST /payments/:community_id/:transaction_id/refund
    def refund(community_id, transaction_id)
      raise NoMethodError.new("Not implemented")
    end

    private

    def with_account(cid, pid)
       m_acc = PaypalService::PaypalAccount::Query.personal_account(pid, cid)
      if m_acc.nil?
        Result::Error.new("Cannot find paypal account for the given community and person: community_id: #{cid}, person_id: #{pid}.")
      else
        yield m_acc
      end
    end

    def with_token(cid, t)
      token = TokenStore.get(cid, t)

      if (token.nil?)
        return Result::Error.new("No matching token for community_id: #{cid} and token: #{t}")
      else
        yield token
      end
    end

    def with_payment(cid, txid)
      payment = PaypalService::PaypalPayment::Query.get(cid, txid)
      if (payment.nil?)
        return Result::Error.new("No matching payment for community_id: #{cid} and transaction_id: #{txid}.")
      end

      m_acc = PaypalService::PaypalAccount::Query.for_payer_id(cid, payment[:receiver_id])
      if m_acc.nil?
        return Result::Error.new("No matching merchant account for community_id: #{cid} and transaction_id: #{txid}.")
      end

      yield payment, m_acc
    end

    def with_success(request)
      response = paypal_merchant.do_request(request)

      if (response[:success])
        yield response
      else
        Result::Error.new("Failed response from Paypal. Code: #{response[:error_code]}, msg:#{response[:error_msg]}")
      end
    end

  end

end