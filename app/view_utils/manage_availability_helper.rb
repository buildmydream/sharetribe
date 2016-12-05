module ManageAvailabilityHelper

  module_function

  def availability_props(community:, listing:,)

    {
      i18n: {
        locale: I18n.locale,
        defaultLocale: I18n.default_locale,
        localeInfo: I18nHelper.locale_info(Sharetribe::AVAILABLE_LOCALES, I18n.locale)
      },
      marketplace: {
        marketplace_color1: CommonStylesHelper.marketplace_colors(community)[:marketplace_color1],
      },
      listing: {
        title: listing.title,
        image_url: path_to_listing_image(listing),
      },
    }
  end

  def path_to_listing_image(listing)
    if !listing.listing_images.empty?
      image = listing.listing_images.first
      if !image.image_ready?
        return images.image.url(:thumb)
      end
    end
    return nil
  end
end
