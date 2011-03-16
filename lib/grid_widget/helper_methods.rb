module GridWidget
  module HelperMethods
    include GridWidget::JqgridSupport::HelperMethods
    
    # I seem to have to do this to get url_for_event working well under a relative path.
    # I probably shouldn't have to
    # TODO: Also see if params[:controller] is the best way to get the controller.
    def rurl_for_event(type, opts = {})
      opts[:controller] = (ENV['RAILS_RELATIVE_URL_ROOT'] ? ENV['RAILS_RELATIVE_URL_ROOT'] + '/' : '') + params[:controller]
      url_for_event(type, opts)
    end
    
  end
end