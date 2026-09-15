import api/auth/auth
import api/user/user
import app/model

pub type Message {
  AuthChecked(auth.CurrentUserResult)
  UserLoaded(user.Result)
  SelectUserTab(model.UserTab)
  OpenAuthModal
  CloseAuthModal
  StartSsoLogin
  NoOp
}
