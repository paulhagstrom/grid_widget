module GridWidget
  module HelperMethods
    # Later I might allow for some kind of configuration to choose the grid.  For now: jqGrid.
    include GridWidget::JqgridSupport::HelperMethods
    
    # I seem to have to do this to get url_for_event working well under a relative path.
    # I probably shouldn't have to
    # TODO: Also see if params[:controller] is the best way to get the controller.
    def rurl_for_event(type, options = {})
      options[:controller] = (ENV['RAILS_RELATIVE_URL_ROOT'] ? ENV['RAILS_RELATIVE_URL_ROOT'] + '/' : '') + params[:controller]
      url_for_event(type, options)
    end

    # wire_filters adds the Javascript watchers to the elements of the filter UI
    # When a filter is clicked, it will call build_filter (defined by #grid_define_get_filter_parms)
    # to append the new selection to the existing selection, and trigger a :filterSelected
    # event that GridListWidget will respond to.
    # wire_filters is called within GridListWidget, so @cell.parent should refer to a GridEditWidget
    def wire_filters
      wiring = <<-JS
      $('##{@cell.parent.dom_id}_list .filter').hover(function(){
          $(this).addClass('filter_hover');
        },function(){
          $(this).removeClass('filter_hover');
        });
      JS
      wiring += grid_define_get_filter_parms
      @cell.parent.filter_sequence.each do |filter_group|
        f = @cell.parent.filters[filter_group]
        f[:sequence].each do |sf|
          wiring += <<-JS
          $('#filter_#{@cell.parent.dom_id}_#{filter_group}_#{sf}').click(function(){
      			$.get('#{rurl_for_event(:filterSelected)}', build_filter_#{@cell.parent.dom_id}('#{filter_group}','#{sf}'), null, 'script');
            });
          JS
        end
      end
      javascript_tag wiring
    end
    
  end
end