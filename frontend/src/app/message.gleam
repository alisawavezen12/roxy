import api/auth/auth
import api/user/user
import app/model

pub type Message {
  AuthChecked(auth.CurrentUserResult)
  UserLoaded(user.Result)
  PostContentChanged(String)
  SelectUserTab(model.UserTab)
  OpenAuthModal
  CloseAuthModal
  OpenSettingsModal
  CloseSettingsModal
  StartSsoLogin
  NoOp
}
