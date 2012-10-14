module ApplicationHelper
  def client_panel?
    controller.module_name == "Client"
  end

  def panel_name
    controller.module_name.downcase
  end

  def login_provider_in_brackets(user = current_user)
    bracketize(user.provider.split("_").first.titleize)
  end

  def bracketize(text)
    "[" + text + "]"
  end

  def user_avatar_and_name_from(comment)
    link = ""
    unless comment.user.image.empty?
      link += image_tag(comment.user.image, :size => "50x50", :alt => "Commentator avatar", :class => %w(pull-left user-avatar))
    end
    link += comment.user.name.strip
  end



  def link_color?(hidden)
    return "muted" if hidden
    ""
  end

  def mark_required(class_object, attribute)
    return "*" if class_object.validators_on(attribute).map(&:class).include? ActiveModel::Validations::PresenceValidator
    ""
  end

  def errors_messages(errors, except)
    errors.
        messages.
        except(*except).
        to_a.map {|elem| elem.first.to_s + " " + elem.last.join(', ') + "<br>" unless elem.last.empty? }
  end

end
