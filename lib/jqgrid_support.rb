# The JqgridSupport module is the place where all of the jqGrid-specific code should go.
# The idea here is that I could someday create a parallel module to support a different grid.
# I'd rather call this GridEdit::JqGridSupport, but Rails didn't like that,
# and it wasn't a priority to figure out why.
module JqgridSupport
  module Controller
  
    # grid_json creates the hash that, when submitted to .to_json, will be in the form
    # that jqGrid requires for its remote fetch.  It is called by GridListWidget#send_json.
    #
    # TODO: This needs to have paging support added
    # TODO: total is supposed to be total pages, records is total number of records.
    def grid_json(rows)
      grid_rows = rows.inject([]) {|a,r| a << {:id => r.id, :cell => grid_json_row(r)}; a} 
      {:total => 1, :page => 1, :records => rows.size, :rows => grid_rows}
    end
  
    # grid_json_row processes one record for #grid_json above.
    # This is the place where :custom field methods are used.
    #
    # Using eval feels funny here, but it allows me to do fairly easy associations like 'record.person.first_name'
    # I faked a 'self' method on the record for use when the custom function should get the whole record.
    def grid_json_row(record)
      @parent.columns.map {|c|
        field_value = eval 'record.' + (c[:field] == 'self' ? 'tap {|x|}' : c[:field]) rescue 'Unset'
        c[:custom] ? @parent.send(c[:custom], field_value) : field_value
        }
    end
    
    # Redraw the grid (re-request the dataset)
    def grid_reload
      "$('##{@container + '_grid'}').trigger('reloadGrid');"
    end
    
    # grid_set_post_params stores the passed hash in jqGrid's postData hash.  This is information
    # that will be sent along with a :fetchData event when it goes to retrieve the data.
    #
    # This is called by GridListWidget#set_filter, which is the receiver for clicks on the filter array.
    #
    # This assumes that parms is a Hash, and it will not replace the entire postData assoc array, 
    # but only those elements whose keys are mentioned in parms.  (This is so changes in filters don't
    # necessarily clobber selected records and vice-versa.)
    def grid_set_post_params(wid, parms)
      set_values = parms.inject('') {|s,(k,v)| s += "gpd['#{k}']=#{v.to_json};"; s}
      <<-JS
      var gpd = $('##{wid}_grid').getGridParam('postData');
      #{set_values}
      $('##{wid}_grid').setGridParam({'postData': gpd});
      JS
    end
    # def grid_set_post_params(parms = {})
    #   <<-JS
    #   $('##{@parent.name}_grid').setGridParam({'postData':#{parms.to_json}});
    #   JS
    # end
    
  end

  module Helper
    
    # support for #wire_filters (defined in grid_widget.rb, GridWidget::Helper)
    # sets up a Javascript function specific to this grid that will append a new filter
    # selection to the existing filter data stored in jqGrid's postData hash, and return
    # it (to be re-stored into the postData hash).
    # TODO: This would be better to define independently, rather than defining it per-grid.
    def grid_define_get_filter_parms
      raw <<-JS
      function build_filter_#{@parent.name}(g,v){
        var gpd = $('##{@parent.name}_grid').getGridParam('postData');
        gpd['filters'] = gpd['filters'] + '|' + g + '-' + v;
        return gpd;
      }
      JS
    end

    # provides the HTML anchor for the table and pager, which jgGrid fills in Javascryptically.
    # presumption is that you will want to "wire" it at the same time (add the JS watchers),
    # but send false for wire_too if you don't.
    def grid_place(domid = 'list_grid', wire_too = true)
      x = raw <<-HTML
  		<table id="#{domid}" class="scroll layout_table" cellpadding="0" cellspacing="0"></table>
  		<div id="#{domid}_pager" class="scroll" style="text-align:center;"></div>
  		HTML
      x + grid_wire(domid) if wire_too
    end

    # grid_wire calls the jgGrid plugin and sets all of the initial parameters.
    def grid_wire(domid = 'list_grid')
      javascript_tag <<-JS
      	$("##{domid}").jqGrid({
      	  #{grid_wire_cell_select}
      		url:'#{rurl_for_event(:fetchData)}',
      		datatype:'json',
      		mtype: 'GET',
      		colModel:[#{grid_columns}],
      		rowNum:#{@parent.grid_options[:rows] || 10},
      		height:#{@parent.grid_options[:height] || 400},
      		//scrollrows:true,
      		//altRows:false,
          // autowidth: true, 
          pager: '##{domid}_pager',
          #{grid_wire_pager}
          #{grid_wire_default_sort}
      		viewrecords: true,
      		caption: '#{@parent.grid_options[:title] || @parent.resource.pluralize.humanize}'
      	});
      #{grid_wire_nav(domid)}
      JS
    end
    
    # Support for #grid_wire
    # sets the click action on the table cells.
    def grid_wire_cell_select
      i, form_columns = @parent.columns.inject([0,[]]) {|a,c| a[1] << a[0] if c[:open_panel] || c[:inplace_edit]; a[0] += 1; a }
      form_columns_js = form_columns.size > 0 ? "(col in {'#{form_columns.join("':'','")}':''})" : 'true'
      <<-JS
      onCellSelect: function(rowid,col,content,event) {
        if (($('##{@parent.name + '_form'}').css('display') == 'block') || (#{form_columns_js})) {
    			$.get('#{rurl_for_event(:cellClick)}', {'id':rowid, 'col':col}, null, 'script');
  			}
      },
      JS
    end
  
    # Support for #grid_wire
    # Return the Javascript columns model (with just the jQGrid options)
    def grid_columns
      omit_options = [:field,:custom,:open_panel,:inplace_edit,:toggle]
      (@parent.columns.map {|c| (c.dup.delete_if{|k,v| omit_options.include?(k)}).to_json}).join(',')
    end
  
    # Support for #grid_wire
    # Sets the default sort if one is defined
    def grid_wire_default_sort
      if ds = @parent.default_sort
        <<-JS
        sortname: '#{@parent.columns[@parent.sortable_columns[ds[0]]][:index]}',
        sortorder: '#{ds[1] ? 'asc' : 'desc'}',
        JS
      end
    end
  
    # Support for #grid_wire
    # Sets the pager options
    def grid_wire_pager
      if @parent.grid_options.has_key?(:pager)
        return <<-JS
         	pginput: true,
        	pgbuttons: true,
        	rowList:#{@parent.grid_options[:pager][:rows_options].to_json || '[]'},
        	rowNum:#{@parent.grid_options[:pager][:rows] || 20},
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
  
    # Support for #grid_wire
    # Set the options for the navigation bar
    def grid_wire_nav(domid)
      if @parent.grid_options[:del_button]
        del_function = <<-JS
        function(id){
          if (confirm('Delete: Are you sure?')) {
      			$.get('#{rurl_for_event(:deleteRecord)}', {'id':id}, null, 'script');
          }
        }
        JS
        prmDel = {
          :url => rurl_for_event(:deleteRecord)
        }.to_json
      else
        prmDel = {}.to_json
      end
      if @parent.grid_options[:add_button]
        add_function = <<-JS
        function(){
    			$.get('#{rurl_for_event(:cellClick)}', {'id':'0'}, null, 'script');
        }
        JS
        prmAdd = {
          :url => rurl_for_event(:deleteRecord)
        }.to_json
      else
        prmAdd = {}.to_json
      end
      prmEdit = prmSearch = prmView = {}.to_json
      <<-JS
      $('##{domid}').jqGrid('navGrid','##{domid}_pager', 
      #{{:edit => false, :add => @parent.grid_options[:add_button], :del => @parent.grid_options[:del_button],
      :addfunc => ActiveSupport::JSON::Variable.new(add_function), :delfunc => ActiveSupport::JSON::Variable.new(del_function),
      :alertcap => 'No record selected', :alerttext => 'You must select a record first.<br />Press Esc to dismiss this warning.',
      :search => false, :refresh => false}.to_json},
      #{prmEdit},#{prmAdd},#{prmDel},#{prmSearch},#{prmView});
      JS
    end
   
  end
end