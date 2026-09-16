import app/message.{type Message}
import app/model.{
  type Model, type Notification, Notification, NotificationError,
  NotificationSuccess,
}
import gleam/option.{type Option}
import lustre/element.{type Element}
import lustre/element/html
import pages/not_found/not_found
import pages/onboarding/onboarding
import pages/user/user
import routes/route.{Home, NotFound, User}
import ui/components/notification/notification
import ui/layout/base_layout/base_layout

pub fn view(model: Model) -> Element(Message) {
  let page = case model.route {
    Home -> onboarding.view(model.auth)
    User(_id) -> user.view(model.user_tab, model.user_page, model.post_content)
    NotFound -> not_found.view()
  }

  html.div([], [
    base_layout.view(
      page,
      model.auth,
      model.auth_modal_open,
      model.settings_modal_open,
      model.sync_state,
      model.logout_state,
      model.bio,
      model.saved_bio,
      model.bio_state,
    ),
    notification.stylesheet(),
    notification_view(model.notification),
  ])
}

fn notification_view(value: Option(Notification)) -> Element(Message) {
  case value {
    option.Some(Notification(NotificationSuccess, message, tooltip)) ->
      notification.view(notification.Success, message, tooltip)
    option.Some(Notification(NotificationError, message, tooltip)) ->
      notification.view(notification.Error, message, tooltip)
    option.None -> html.div([], [])
  }
}
