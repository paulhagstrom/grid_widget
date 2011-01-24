# GridEditWidget is a widget that displays a form and handles submission.
# Under normal circumstances, it will also have a GridListWidget as a child.
#
# The basic use case would be to have a list of records (displayed by the child GridListWidget)
# which allows editing of individual records as they are selected.
#
# To use a GridEditWidget, something like the following should be placed in the controller.
# Each GridEditWidget has a "resource" (which is basically the model where the data being
# edited and listed comes from).  A few different names are derived from the resource name,
# which can be individually set if necessary, but in the most basic form just the resource
# can be named.  The resource should be the name of a model, in underscore form.
#
#   include Apotomo::Rails::ControllerMethods
#   include GridWidget::Controller
# 
#   has_widgets do |root|
#     root << grid_edit_widget('contact') do |c|
#       [...configuration options...]
#     end
#   end
#
# In the example above, the model will be +Contact+, and it will create a widget with
# an id of +contact_widget+.  To choose a different widget_id, pass in a <tt>:widget_id</tt>
# parameter.  Other options passed to +grid_edit_widget+ will be passed on to the
# widget for storage in its parameters/options.
# +grid_edit_widget+ is defined in <tt>grid_widget.rb</tt>.
#
#     root << grid_edit_widget('contact', :widget_id => 'wid', :beer => :insufficient) do |c|
#       [...configuration options...]
#     end
#
# Most configuration options have a sensible default, so for a very simple widget you
# can get away with doing nothing but defining the columns.  In that case, it will expect
# to find the template for the form in <tt>app/cells/grid_edit_widget/[resource].html.erb</tt>.
# That is:
#
#   has_widgets do |root|
#     root << grid_edit_widget('contact') do |c|
#       c.add_column('code')
#       c.add_column('name')
#     end
#   end
#
# Several basic configuration options are simply attributes that can be set in the
# configuration block.
#
# Grid DOM id::
#   +dom_id+ (attribute), defaults to resource_widget (like widget_id)
# Grid options::
#   +grid_options+ (attribute)
# Query options::
#   +includes+ (attribute), defaults to nothing, but if set will cause
#   eager loading, for use in custom output methods.
# Form template name::
#   +form_template+ (attribute),
#   looks in <tt>app/cells/grid_form_widget/form/</tt> for <tt>{form_template}.html.erb</tt>, and
#   defaults to <tt>{controller}</tt>.
# Where clause for sub-widgets::
#   +where+ (attribute), define with lambda expecting parent id.
#   Defaults to +nil+, meaning that the widget is independent.
#
# There are a few configuration methods that are defined for the purpose of building
# up the column and filter models.  These are documented more fully by their own definitions.
#
# Column options::
#   +add_column+ to define the columns in the grid
# Filter options::
#   +add_filter_group+ and +add_filter+ to create filters for the grid
#
# It is also possible in the configuration block to define custom output methods
# used by the grid to format the display.  See the example below for one such definition.
# They are referred to in the column model, when a +:custom+ parameter is passed.
# There are a couple of these methods already predefined here that can be used.
# 
# * +custom_yn+ (for booleans, display 'Yes' if true otherwise 'No')
# * +custom_check+ (like +custom_yn+, but displays a checkmark or nothing)
# * +custom_abbrev+ (for long strings, cuts it off at 20 characters and provides ellipses)
#
# There are also a couple of hooks that can be overridden within the configuration block,
# discussed more below.  Obvious candidates for this are +fetch_record+ and 
# +after_form_update+.
#
# The configuration options can all be set in a single configuration block and intermixed,
# though order does matter when defining columns and filters.
#
#   has_widgets do |root|
#     root << grid_edit_widget('contact') do |c|
#       c.grid_options {:title => 'Contacts list'}
#       c.includes :categories
#       c.add_column('name', :custom => :custom_name)
#       def c.custom_name(name)
#         "[#{name}]"
#       end
#       c.add_filter_group('categories', :where => lambda {|x| {category_id => x}}) do |g|
#         Category.all.each {|cat| g.add_filter(cat.id, cat.name)}
#       end
#     end
#   end
#
# GridEditWidgets can contain other GridEditWidgets. This would arise, for example,
# if you are editing a user model which might have many contact records.  In the
# form for the user widget, you might have a contact widget that displays the contacts
# for the displayed user and allows editing of the contacts.  To accomplish this,
# the +#embed_widget+ method should be called.  An embedded widget is usually dependent
# on the parent selection (so, e.g., we only want the contacts from the selected user),
# so a where clause is required when embedding the widget that will narrow the scope to
# just the relevant records.  The where clause is a lambda function which will provide
# this scope when passed the id of the parent selection (what is returned is handed
# off to ActiveRecord's +where+ method, so what is returned should be a Hash).
# For example:
#
#   c.embed_widget lambda {|x| {:user_id => x}}, contact_widget
#
# The procedure above is used to embed widgets for +has_many+ relations.
# It is also possible to embed a GridWidget for a +belongs_to+ relation, in which case
# you want a widget that does not have an attached list.  The use case envisioned here
# is one where, say, a profile record belongs_to user, and the main widget has profile
# as its resource. When a profile is being edited, the user fields can also be on the
# screen for editing.  And, when a new profile is being created, these can be used to
# create a new user record.  To set this up, +grid_edit_widget+ should be sent a
# <tt>:form_only</tt> parameter, which is a lambda function returning the id of the parent
# when passed the id of the child.  For example:
#
#   user_widget = grid_edit_widget('user', :form_only => lambda {|x| Profile.find(x).user_id}) do ...
#
# This should then be embedded using +embed_widget+ without a +where+ clause:
#
#   c.embed_widget nil, user_widget
#
# If a new record is being added in this situation, and no parent record is selected,
# then any other child widgets will render <tt>display_orphan.html.erb</tt>, which basically
# says that you need a parent record before you can start adding children.  In this
# example, if you create a new profile, the first step is to create a user that it
# belongs to, before you can start creating contacts for the user.  You can point to
# your own orphan template (to provide more customized instructions) by setting the
# +orphan_template+ option.  This will be sought for in the application views directory.
#
#   c.orphan_template = 'contacts_orphan'
#
# This situation where a form embeds a widget corresponding to a belongs_to association
# also may lead one to want to attach certain actions to record creation.  This might
# also arise if you want to automatically set certain fields (like filling in the author
# of a comment posting).  The suggested approach for this is to override +fetch_record+
# to do something like the following, which will check to see if a record that would have
# been added to the user table already exists, and will load the existing record instead
# if so.
#
#   def c.fetch_record(use_scope = true, attributes = {})
#     record = super(use_scope, attributes)
#     if record.new_record? && (users = User.where({:username => record.username}).all).size > 0
#       record = users.first
#     end          
#     record
#   end
#
# The +fetch_record+ method needs to accept the +use_scope+ and +attributes+ parameters,
# and return the record (possibly a +new+ record for the model), but most of the basic
# functionality can be handled by +super+.
#
# Once a new record is added, the +after_form_update+ method is called, and this can
# be overridden if one wants to, e.g., add certain child records once the parent is
# created.  +after_form_update+ has access to the id, whereas +fetch_record+ doesn't.
# So, for example, if a default contact record should be added once a new user is created,
# you could do this:
#
#   def c.after_form_update(record, was_new, form_action)
#     profile = Profile.where(:user_id => record.id).first
#     if was_new
#       new_contact = Contact.create(:user_id => record.id,
#         :data => "#{record.username}@example.com")
#     end
#     return {:pid => record.id, :id => profile.id}
#   end
#
# The +after_form_update+ method must accept the record, a boolean +was_new+ flag that
# will be true if the record has just been added (and false if this was an edit of an
# existing record), and the string +form_action+ which will reflect which button was
# pressed on the form (this code will never be called if the button pressed was 'cancel',
# but it is possible to add custom buttons that might be used to affect the flow of control
# here).  If +after_form_update+ returns something other than +nil+ then a +recordSelected+
# event is triggered with the return value.
# TODO: This is a place where things are kind of clunky.  It works for what I was trying
# to do, but the retrieval of the profile.id is fragile and I want to rethink how this works.
#
class GridEditWidget < Apotomo::Widget
  include GridWidget::ControllerMethods
  include GridWidget::ConfigMethods
  include GridWidget::CustomDisplayMethods
  include GridWidget::AppSupport::ControllerMethods
  helper GridWidget::HelperMethods
  
  attr_accessor :includes
  attr_accessor :grid_options
  attr_accessor :dom_id
  attr_accessor :form_template
  attr_accessor :form_buttons
  attr_accessor :orphan_template
  attr_accessor :where
  attr_accessor :record
  attr_reader :resource
  attr_reader :columns, :sortable_columns, :default_sort
  attr_reader :filters, :filter_sequence
  attr_reader :filter_default
  attr_reader :form_only
  attr_reader :list_widget_id
  
  after_initialize :setup

  # TODO: Try this later
  # responds_to_event :formSubmit, :with => :form_submitted
  
  after_add do |me, parent|
    me.respond_to_event :formSubmit, :from => me.name, :with => :form_submitted, :on => me.name
  end
  
  # Draw the empty form (and the child list widget, which will render first)
  def display
    my_params = get_request_parameters
    if @form_only
      @record = fetch_record
      render :view => @form_template, :layout => 'form_only_wrapper', :locals =>
          {:container => @dom_id + '_form', :resource => @resource, :record => @record}
    else
      if @where && !my_params[:pid]
        render :view => @orphan_template
      else
        render
      end
    end
  end
    
  # #display_form catches the :recordSelected event that originates from the list #cell_click method.
  # Emits the JS to populate and reveal the form.
  def display_form
    # The 1-arity form of this, which is supposed to retrieve the event, isn't working for me.
    # fetch_record makes use of @opts[:event]
    @record = fetch_record
    # Make a new form div so we can slide away the old one and swap ids
    # (This all relies on the id of the form corresponding to an enclosing div, incidentally)
    form = @dom_id + '_form'
    clone_form = <<-JS
    var new_form = $('##{form}').clone().hide().css('background-color','#DDDDFF');
    $('##{form}').attr('id', 'ex_#{form}');
    $('#ex_#{form}').find('[id]').attr('id', function(){return 'ex_' + this.id;});
    // These elements are no more.  They have ceased to be.  Bereft of life, they rest in peace.
    // This is an ex_form!
    new_form.insertAfter('#ex_#{form}');
    JS
    # slide in the new one and slide out and destroy the old one
    swap_display = <<-JS
    $('##{form}').slideDown('fast');
    $('#ex_#{form}').slideUp('fast', function() { $(this).remove();});
    JS
    render :text => clone_form + update_form_content(@record) + swap_display
  end
  
  # TODO: This really looks like I have form_only_wrapper and form_wrapper reversed.  Check and fix.
  # Also, form_wrapper and form_only_wrapper are super-un-DRY, why do I have both?
  def update_form_content(record)
    update(:selector => @dom_id + '_form', :view => @form_template,
      :layout => @form_only ? 'form_wrapper' : 'form_only_wrapper', :locals =>
      {:container => @dom_id + '_form', :resource => @resource, :record => record}) + ';'
  end
  
  # #form_submitted catches the :formSubmit event from the form (defined in the form_wrapper layout).
  # Updates the record with attributes in the (@dom_id + '_form') hash (default: resource_widget_form)
  def form_submitted
    # TODO: Check. This might be a bit insecure at the moment 
    unless param(:form_action) == 'cancel'
      attributes, special = get_form_attributes
      @record = fetch_record(false, attributes)
      was_new = @record.new_record?
      @record.update_attributes(attributes)
      reaction = after_form_update(:record => @record, :was_new => was_new,
        :form_action => param(:form_action), :special => special)
      trigger(:recordSelected, reaction[:recordSelected]) if reaction[:recordSelected]
      trigger :recordUpdated
      render :text => reaction[:text]
    else
      render :text => turn_and_deveal_form('#FF8888')
    end
  end
  
  # get_form_attributes pulls the record's attributes from the form, override if you need to
  # process these before handing them back.  It returns a two-member array, the first member
  # being the attributes that correspond to the model, the second being the form entries
  # that don't have a correspondent in the model (e.g., a checkbox use to trigger some action).
  # This can be used unchanged if the extra things are in the dom_id_form_special array.
  def get_form_attributes
    [param(@dom_id + '_form'), param(@dom_id + '_form_special')]
  end
    
  # #after_form_update is a hook that allows you to react to record creation (e.g., create a child record)
  # just after it is added/saved (when the id is available).  Override as needed.
  # #form_submitted will send a number of parameters in an options hash.
  # the return hash should include a :text key that holds the Javascript to render.
  # If the return hash includes a :recordSelected key, it will trigger :recordSelected with the value.
  def after_form_update(options = {})
    reaction = options[:reaction] || {}
    if @form_only || options[:form_action] == 'remain'
      reaction[:text] = pulse_form
    else
      reaction[:text] = turn_and_deveal_form
    end
    reaction
  end
  
  # Forms the Javascript that will pulse the background color of the form (signaling save)
  def pulse_form(color = '#88FF88')
    form = @dom_id + '_form'
    <<-JS
    var origColor = $('##{form}').css('background-color');
    $('##{form}').animate({backgroundColor: '#{color}'}, 100).animate({backgroundColor:origColor}, 1000);
    JS
  end

  # Forms the Javascript that will change the background color of the form and slide it away.
  # This is included in the responses to hitting update or cancel.
  # The color is supposed to signal whether it is an update or a cancel (default is green for update).
  # TODO: Use CSS
  def turn_and_deveal_form(color = '#88FF88')
    form = @dom_id + '_form'
    <<-JS
    $('##{form}').css('background-color','#{color}').slideUp('fast');
    JS
  end

  # #delete_record catches the :deleteRecord event posted by the grid when the delete button is hit.
  # Deletes the selected record, cancels the form, and posts :recordUpdated to get the list to redraw.
  def delete_record
    if record = fetch_record
      record.destroy
    end
    trigger :recordUpdated
    render :text => turn_and_deveal_form('#FF8888')
  end
  
  # #edit_record catches the :editRecord event posted by the grid for editing in place.
  # At this point, it only handles toggling boolean values.
  # TODO: Allow for other editing in place.
  # When an in-place edit happens, the form is canceled because it *could* have been the one we
  # were editing.
  # TODO: Make this smarter so that it will cancel the form only if it *is* the one we are editing.
  # TODO: Or make it even smarter and have it update the value in the form rather than cancel.
  def edit_record
    c = @columns[param(:col).to_i]
    if c[:inplace_edit]
      record = fetch_record
      if c[:toggle]
        f = c[:field]
        v = record.send(f)
        record.update_attributes({f => !v})
      end
      record.save
      trigger :recordUpdated
      render :text => turn_and_deveal_form('#FF8888')
    else
      render :nothing => true
    end
  end
  
  # #fetch_record loads either a new record or the record for which an ID was passed.
  # TODO: Should #fetch_record be private?
  # The use_scope parameter is set to false on the return from a form submit, since in that case the ID is for
  # the targeted resource and not for the parent's resource.
  # The attributes parameter will populate a new record
  # You can override fetch_record if you want to add something as the record is created (like user id),
  # just def fetch_record(use_scope = true, attributes = {}); super(use_scope,attributes); return the record
  def fetch_record(use_scope = true, attributes = {})
    # If the parent already has an id, use it.
    # If the event sent us an id or pid, use it, otherwise go for the request parameters
    recid = (@form_only && parent.record && parent.record.id) ? parent.record.id :
      (@opts[:event] && @opts[:event].data[:id].to_i > 0) ? @opts[:event].data[:id].to_i : 
      param(:id).to_i    
    pid = (@opts[:event] && @opts[:event].data[:pid].to_i > 0) ? @opts[:event].data[:pid].to_i :
      param(:pid).to_i
    if recid > 0
      if @form_only && use_scope
        record = (Object.const_get @resource.classify).includes(@includes).find(@form_only.call(recid))
      else
        record = (Object.const_get @resource.classify).includes(@includes).find(recid)
      end
    else
      if @where && use_scope
        record = (Object.const_get @resource.classify).where(attributes).where(@where.call(pid)).new
      else
        record = (Object.const_get @resource.classify).where(attributes).new
      end
    end
  end
      
  # #get_request_parameters inspects the request parameters, mostly to sanitize and update
  # the filters.  It will also catch the parent's id (for subordinate forms).
  #
  # Filter parameters come in as a string in :filters in the following format:
  # filters = group1-val1-val2-val3|group2-vala-valb-valc|group1-val4
  # if a group repeats, the later values toggle existing, e.g., above group1 will have val4
  # if it had ended in group1-val2, then val2 would have been removed from group1
  # TODO: Investigate using real arrays, it would be simpler than having to parse this much.
  def get_request_parameters
    return_filters = {}
    # If the parent has a record already, use it in preference to the request parameter
    pid = (parent.is_a?(GridEditWidget) && parent.record) ? parent.record.id : param(:pid)
    return_params = pid ? {:pid => pid} : {}
    if param(:filters)
      # parse the filters parameter
      filters = []
      (filter_groups = param(:filters).split('|')).each do |f|
        filter_parts = f.split('-')
        filter_group = filter_parts.shift
        filters << [filter_group, filter_parts]
      end
      # verify the filters, make delta changes
      filters.each do |group, filter_ids|
        if @filter_sequence.include?(group)
          return_filters[group] ||= []
          filter_ids.each do |filter_id|
            if @filters[group][:sequence].include?(filter_id)
              if @filters[group][:options].has_key?(:exclusive)
                return_filters[group] = return_filters[group].include?(filter_id) ? [] : [filter_id]
              else
                if return_filters[group].include?(filter_id)
                  return_filters[group].delete(filter_id)
                else
                  return_filters[group] << filter_id
                end
              end
            end
          end
        end
      end
    end
    unless return_filters.size > 0
      # No (valid) filters, so return the default if there is one
      @filter_default.each do |df|
        g, f = df
        return_filters[g] ||= []
        return_filters[g] << f
      end
    end
    return_params[:filters] = (return_filters.size > 0) ? return_filters : nil
    return_params
  end
  
  # This can be overridden if the caption needs to change dynamically
  def caption
    @grid_options[:title] || @resource.pluralize.humanize
  end
  
  def add_form_button(buttonspec)
    @form_buttons << buttonspec
  end
  
  private
  
  # Called by after_initialize, will set the defaults prior to executing the configuration block.
  def setup(*)
    @resource = param(:resource)
    @form_only = param(:form_only)
    @where = param(:where)
    
    @dom_id = @resource + '_widget'

    @grid_options = {}
    
    @columns = []
    @sortable_columns = {}
    @default_sort = nil
    
    @filters = {}
    @filter_sequence = []
    @filter_default = []
    
    # Guesses that you will be using the form template matching the name of your controller
    # This can be overridden in the configuration, but defaults to 'authors' for AuthorsController
    @form_template = parent_controller.class.name.underscore.gsub(/_controller$/,'')
    # The orphan template is used when a parent record is needed but not selected
    @orphan_template = 'display_orphan'
    
    unless @form_only
      # create the child list widget
      @list_widget_id = @dom_id + '_list'
      self << widget(:grid_list_widget, @list_widget_id, :display)
      @form_buttons = [
        ['submit', 'Save+Close', 'Add+Close'],
        ['remain', 'Save', 'Add'],
        ['cancel', 'Cancel', 'Cancel'],
      ]
    else
      @form_buttons = [
        ['remain', 'Save', 'Add'],
      ]
    end
  end
end
