import * as actionTypes from '../constants/ManageAvailabilityConstants';

const initialState = {

};

export default function manageAvailabilityReducer(state = initialState, action) {
  const { type } = action;

  switch (type) {
    case actionTypes.ALLOW_DAY:
      // TODO: mark day as allowed in the pending list
      return state;
    case actionTypes.BLOCK_DAY:
      // TODO: mark day as blocked in the pending list
      return state;
    case actionTypes.CHANGE_MONTH:
      // TODO: fetch more data
      return state;
    case actionTypes.SAVE_CHANGES:
      // TODO: save pending changes
      return state;
    case actionTypes.CLOSE_EDIT_VIEW:
      // TODO: confirm if there are unsaved changes
      // TODO: mark winder closed
      return state;
    default:
      return state;
  }
}
