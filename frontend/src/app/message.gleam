import api/auth/auth
import api/user/user

pub type Message {
  AuthChecked(auth.CurrentUserResult)
  UserLoaded(user.Result)
  OpenAuthModal
  CloseAuthModal
  StartSsoLogin
  NoOp
}
