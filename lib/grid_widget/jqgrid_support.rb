# The JqgridSupport module is the place where all of the jqGrid-specific code resides.
# The idea here is that I could someday create a parallel module to support a different grid.
# This is mixed into GridListWidget.
#
# The JqgridSupport module has a number of critical methods that will need to be
# converted if another grid is to be supported.
#
# * +grid_json+ returns the table data for display in the format the grid expects.
# * +grid_reload+ causes the grid to refresh itself (and re-request the data).
# * +grid_set_post_params+ stores information in the grid's user space.
# * +grid_event_spec+ returns the column and id of a row click event
# * +grid_get_sort+ returns the column number and sort order (ASC/DESC) of the current sort.
# * +grid_get_pagination+ returns the current page and number of rows of the current page
# * +grid_place+ emits the HTML for the basic table, and wires it up.
#
# Here, there are several other methods as well that factor out various parts of the
# +grid_place+ method.  Most of the grid-specific parameters apart from DOM id are
# dealt with in +grid_place+, and it should be clear when re-writing that method how
# to translate the options for a different grid.
module GridWidget
  module JqgridSupport
    module ControllerMethods
  
      # grid_json creates the hash that, when submitted to .to_json, will be in the form
      # that jqGrid requires for its remote fetch.
      def grid_json(rows)
        grid_rows = rows.inject([]) {|a,r| a << {:id => r.id, :cell => grid_json_row(r)}; a} 
        {:total => total_pages, :page => current_page, :records => total_records, :rows => grid_rows}
      end
  
      # grid_json_row processes one record for #grid_json above.
      # This is the place where :custom field methods are used.
      #
      # Using eval allows me to do fairly easy associations like 'record.person.first_name'
      # If the custom takes two parameters, the second one passed will be the record.
      # If the virtual flag is set then it won't try to evaluate the field against the record.
      def grid_json_row(record)
        parent.columns.map {|c|
          field_value = c[:virtual] ? '' : (eval 'record.' + c[:field] rescue 'Unset')
          c[:custom] ?
            ((parent.method(c[:custom]).arity == 2) ?
              parent.send(c[:custom], field_value, record) :
              parent.send(c[:custom], field_value)
            ) :
            field_value
          }
      end
    
      # Redraw the grid (re-request the dataset) and reset the caption in case it changed
      def grid_reload
        <<-JS
        $('##{parent.dom_id}_grid').setCaption('#{parent.caption}');
        $('##{parent.dom_id}_grid').trigger('reloadGrid');
        JS
      end
    
      # grid_event_spec returns a hash with col (column number) and id (record id) from a row click event
      def grid_event_spec(evt)
        {:col => evt[:col].to_i, :id => evt[:id], :parms => evt[:postData]}
      end
      
      # grid_set_post_params stores the passed hash in jqGrid's postData hash.  This is information
      # that will be sent along with a :fetch_data event when it goes to retrieve the data.
      #
      # This is called by GridListWidget#set_filter, which is the receiver for clicks on the filter array.
      #
      # This assumes that parms is a Hash, and it will not replace the entire postData assoc array, 
      # but only those elements whose keys are mentioned in parms.  (This is so changes in filters don't
      # necessarily clobber selected records and vice-versa.)
      def grid_set_post_params(parms)
        set_values = parms.inject('') {|s,(k,v)| s += "gpd['#{k}']=#{v.to_json};"; s}
        <<-JS
        var gpd;
        gpd = $('##{parent.dom_id}_grid').getGridParam('postData');
        if(typeof gpd == 'undefined') gpd = {};
        #{set_values}
        $('##{parent.dom_id}_grid').setGridParam({postData: gpd});
        JS
      end
      
      # determine the column and sorting order currently selected, based on the event parameters
      # returns an array: [sort_column_number, sort_order]
      # TODO: If jqgrid supports multiple sorts, maybe someday put that in.
      def grid_get_sort(evt)
        [evt[:sidx], (evt[:sord] == 'desc' ? 'DESC' : 'ASC')]
      end

      # determine the pagination parameters currently selected, based on the event parameters
      # returns an array: [page, rows]
      def grid_get_pagination(evt)
        [evt[:page].to_i, evt[:rows].to_i]
      end
    end

    module HelperMethods
    
      # provides the HTML anchor for the table and pager, and wires it (jgGrid fills it in Javascryptically).
      def grid_place
        grid_dom_id = controller.parent.dom_id + '_grid'
        x = raw <<-HTML
    		<table id="#{grid_dom_id}" class="scroll layout_table" cellpadding="0" cellspacing="0"></table>
    		<div id="#{grid_dom_id}_pager" class="scroll" style="text-align:center;"></div>
    		HTML
        x += javascript_tag <<-JS
        	$("##{grid_dom_id}").jqGrid({
        	  #{grid_wire_cell_click}
        		url:'#{rurl_for_event(:fetch_data)}',
        		datatype:'json',
        		mtype: 'GET',
        		colModel:[#{grid_columns}],
        		hiddengrid:#{controller.parent.grid_options[:hiddengrid] || false},
        		rowNum:#{controller.parent.grid_options[:rows] || 10},
        		height:#{controller.parent.grid_options[:height] || 400},
        		//scrollrows:true,
        		//altRows:true,
            //autowidth: true, 
            pager: '##{grid_dom_id + '_pager'}',
            #{grid_wire_pager}
            #{grid_wire_default_sort}
            #{grid_wire_set_pid}
        		viewrecords: true,
        		caption: '#{controller.parent.caption}'
        	});
        #{grid_wire_activate_titlebar}
        #{grid_wire_nav}
        JS
        x
      end
    
      # Support for #grid_place
      # If the data in this grid depends on a parent selection
      # (which we know because the GridEditWidget's where is set),
      # then add the id of the parent's record in the postData as 'pid', if it is known.
      def grid_wire_set_pid
        return '' unless controller.parent.where && controller.parent.parent.record && controller.parent.parent.record.id
        <<-JS
        postData: {'pid':#{controller.parent.parent.record.id}},
        JS
      end
    
      # Support for #grid_place
      # sets the click action on the table cells.  Triggers a cell_click event on the list widget
      def grid_wire_cell_click
       <<-JS
       onCellSelect: function(rowid,col,content,event) {
  			  $.get('#{rurl_for_event(:cell_click)}', {'id':rowid, 'col':col}, null, 'script');
       },
       JS
      end
      
      # Support for #grid_place
      # Return the Javascript columns model (with just the jQGrid options)
      def grid_columns
        omit_options = [:field,:custom,:open_panel,:inplace_edit,:toggle,:spokesfield,:virtual]
        (controller.parent.columns.map {|c| (c.dup.delete_if{|k,v| omit_options.include?(k)}).to_json}).join(',')
      end
  
      # Support for #grid_place
      # Sets the default sort if one is defined
      def grid_wire_default_sort
        if ds = controller.parent.default_sort
          <<-JS
          sortname: '#{controller.parent.columns[controller.parent.sortable_columns[ds[0]]][:index]}',
          sortorder: '#{ds[1] ? 'asc' : 'desc'}',
          JS
        end
      end
  
      # Support for #grid_place
      # Sets the pager options
      def grid_wire_pager
        if controller.parent.grid_options.has_key?(:pager)
          return <<-JS
           	pginput: true,
          	pgbuttons: true,
          	rowList:#{controller.parent.grid_options[:pager][:rows_options].to_json || '[]'},
          	rowNum:#{controller.parent.grid_options[:pager][:rows] || 20},
          JS
        else
          return <<-JS
           	pginput: false,
          	pgbuttons: false,
          	rowList: [],
          	rowNum: -1,
          JS
        end
      end
  
      # Support for #grid_place
      # Set the options for the navigation bar
      def grid_wire_nav
        if controller.parent.grid_options[:del_button]
          del_function = <<-JS
        			$.get('#{rurl_for_event(:delete_record)}', {'id':id}, null, 'script');
          JS
          # only do the delete confirmation if we don't have a paper trail on the model
          unless controller.parent.resource_model.method_defined?(:versions)
            del_function = <<-JS
              if (confirm('Delete: Are you sure?')) {
          			#{del_function}
              }
            JS
          end
          del_function = <<-JS
          function(id){
            #{del_function}
          }
          JS
        else
          del_function = "function(id){}"
        end
        # Changing add button behavior from cell_click to add_button
        if controller.parent.grid_options[:add_button]
          # postData for the grid will contain the parent id (pid) if this grid depends on it.
          add_function = <<-JS
          function(){
      			$.get('#{rurl_for_event(:add_button)}', {'pid':$('##{controller.parent.dom_id}_grid').getGridParam('postData')['pid']}, null, 'script');
          }
          JS
        else
          add_function = "function(){}"
        end
        prmEmpty = {}.to_json
        <<-JS
        $('##{controller.parent.dom_id}_grid').jqGrid('navGrid','##{controller.parent.dom_id}_grid_pager', 
        #{{:edit => false, :add => controller.parent.grid_options[:add_button], :del => controller.parent.grid_options[:del_button],
        :addfunc => ActiveSupport::JSON::Variable.new(add_function), :delfunc => ActiveSupport::JSON::Variable.new(del_function),
        :alertcap => 'No record selected', :alerttext => 'You must select a record first.<br />Press Esc to dismiss this warning.',
        :search => false, :refresh => false}.to_json},
        #{prmEmpty},#{prmEmpty},#{prmEmpty},#{prmEmpty},#{prmEmpty});
        JS
      end
   
      def grid_wire_activate_titlebar
        <<-JS
        // make clicking on the caption the same as click on the collapse icon.
      	var v = $('##{controller.parent.dom_id}_grid').closest('.ui-jqgrid-view');
      	v.find('.ui-jqgrid-titlebar').click(function() {
      		$(this).find('.ui-jqgrid-titlebar-close').trigger('click');
      		});
        JS
      end
    end
  end
end
