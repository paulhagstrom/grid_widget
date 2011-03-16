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
#   include GridWidget::Controller
# 
#   has_widgets do |root|
#     root << grid_edit_widget('contact') do |c|
#       [...configuration options...]
#     end
#   end
#
# In the example above, the model will be +Contact+, and it will create a widget with
# an id of +contact+.  To choose a different widget_id, pass in a +:widget_id+
# parameter.  Other options passed to +#grid_edit_widget+ will be passed on to the
# widget for storage in its parameters/options.
# +grid_edit_widget+ is defined in <tt>grid_widget.rb</tt>.
#
#     root << grid_edit_widget('contact', :widget_id => 'wid', :beer => :insufficient) do |c|
#       [...configuration options...]
#     end
#
# Most configuration options have a sensible default, so for a very simple widget you
# can get away with doing nothing but defining the columns.  In that case, it will expect
# to find the template for the form in app/widgets/grid_edit_widget/[resource].html.erb.
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
# Base DOM id:: +dom_id+ (attribute), defaults to resource
# Grid options:: +grid_options+ (attribute)
# Query options:: +includes+ (attribute), defaults to nothing, but if set will cause
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
  
  # attributes that you can set in the configuration block
  attr_accessor :dom_id
  attr_accessor :includes
  attr_accessor :grid_options
  attr_accessor :form_template
  attr_accessor :form_buttons
  attr_accessor :orphan_template
  attr_accessor :where
  attr_accessor :record
  # internal attributes not intended for configuration block
  # for columns and filters, use add_column, add_filter, add_filter_group (in ConfigMethods)
  # These are consulted by the child widget
  attr_reader :list_widget
  attr_reader :filters_widget
  attr_reader :columns, :sortable_columns, :default_sort
  attr_reader :filters, :filter_sequence
  attr_reader :filter_default
  
  # because resource and form_only are used in the pre-configuration block setup
  # they must be set as widget options
  after_initialize :setup
  
  after_add do |me, mom|
    me.respond_to_event :form_submitted, :from => me.name
  end
    
  def display
    # for "form only" widget, we find this resource's record based on an id in the parent's record
    # TODO: This makes more db queries than necessary. Make form_only depend on record not id?
    if options[:form_only]
      set_record (parent.record.id.to_i > 0) ? options[:form_only].call(parent.record.id) : 0
      render form_content_options
    else
      # for child widgets (where the list depends on a parent's selection), show orphan if none selected
      if where && parent.record.id.to_i == 0
        render :view => orphan_template
      else
        render
      end
    end
  end
    
  # #display_form catches the :display_form event that originates from the list #cell_click method.
  # #display_form can also be triggered by a form submission
  # BUT RIGHT NOW THAT IS UNCAUGHT UNLESS THIS IS AN EMBEDDED WIDGET.  APPROPRIATE?  HANDLER INSTALLED IN embed_widget.
  # Emits the JS to populate and reveal the form.
  def display_form(evt)
    set_record evt[:id], evt[:pid]
    render :text => update("##{dom_id}_form", form_content_options(evt[:pid])),
      :layout => 'form_reveal.js.erb',
      :locals => {:form_selector => "#{dom_id}_form"}
  end

  # form_content_options are sent to either update or render to fill in the form
  def form_content_options(pid = nil)
    {:view => form_template, :layout => 'form_wrapper',
      :locals => {:container => "#{dom_id}_form", :record => record, :pid => pid}}
  end
    
  # #form_submitted catches the :form_submitted event from the form (defined in the form_wrapper layout).
  # Updates the record with attributes in the (@dom_id + '_form') hash (default: resource_widget_form)
  def form_submitted(evt)
    unless evt[:form_action] == 'cancel'
      attributes = evt["#{dom_id}_form".to_sym]
      set_record evt[:id], evt[:pid]
      was_new = record.new_record?
      record.update_attributes(attributes)
      # call the after_form_update hook, which can trigger selection options .. ?
      if select_options = after_form_update(record, was_new, evt[:form_action])
        trigger :display_form, select_options
      end
      trigger :reload_grid
      # After the form is submitted, the form can either be closed, or we can stay.
      # If this is a form_only widget, we have to stay.
      # TODO: Is there any way to go to next/prev? Perhaps this is what select_options can do for us?
      if options[:form_only] || evt[:form_action] == 'remain'
        # TODO: Consider whether I want to make it (an option to) redraw everything.
        render :text => form_pulse
      else
        render :text => form_deveal
      end
    else
      render :text => form_deveal('#FF8888') #cancel
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
  
  # JS to pulse the background color of the form (signaling save)
  def form_pulse(color = '#88FF88')
    render :view => 'form_pulse', :locals => {:form => "#{dom_id}_form", :color => color}
  end

  # JS to change the background color of the form and slide it away.
  # The color is supposed to signal update (default, green) or cancel (e.g., '#FF8888' red).
  def form_deveal(color = '#88FF88')
    render :view => 'form_deveal', :locals => {:form => "#{dom_id}_form", :color => color}
  end

  # #delete_record catches the :delete_record event posted by the grid when the delete button is hit.
  # Deletes the selected record, cancels the form, and posts :reload_grid to get the list to redraw.
  # def delete_record
  # TODO: Allow delete button from form?
  def delete_record(evt)
    set_record evt[:id]
    record.destroy if record.id
    trigger :reload_grid
    render :text => form_deveal('#FF8888') #cancel
  end
  
  # #inplace_edit catches the :inplace_edit event posted by the cell_click handler for editing in place.
  # At this point, it only handles toggling boolean values.
  # TODO: Allow for other editing in place.
  # When an in-place edit happens, the form is canceled because it *could* have been the one we
  # were editing.
  # TODO: Make this smarter so that it will cancel the form only if it *is* the one we are editing.
  # TODO: Or make it even smarter and have it update the value in the form rather than cancel.
  def inplace_edit(evt)
    c = @columns[evt[:col].to_i]
    if c[:inplace_edit]
      set_record evt[:id]
      if c[:toggle]
        f = c[:field]
        v = record.send(f)
        record.update_attributes({f => !v})
      end
      record.save
      trigger :reload_grid
      render :text => form_deveal('#FF8888') #cancel
    else
      render :nothing => true
    end
  end
  
  # #embed_widget is used to embed a subordinate grid_edit_widget into the form of this one.
  # In the form, you would put, e.g., <%= render_widget :contact %> to specify the
  # place where the sub-widget will appear.
  # Intended to be called from either a controller or another GridEditWidget (e.g., in setup)
  # This is called with a 'where' clause that will be used when the records are loaded.
  # It should be a lambda function which is passed an id, e.g., lambda {|x| {:person_id => x}}
  # The 'where' clause is required, it tells the widget that it is subordinate.
  # The wiring here: if the child edit widget posts a reload_grid event, send it to our list.
  # If the child posts a display form, send it to ourselves.
  # TODO: Track this wiring to see if it is correct.
  def embed_widget(where, wid)
    self << wid
    wid.where = where
    respond_to_event :reload_grid, :from => wid.name, :with => :reload_grid, :on => list_widget
    respond_to_event :display_form, :from => wid.name, :with => :display_form, :on => name
  end
      
  # This can be overridden if the caption needs to change dynamically
  def caption
    grid_options[:title] || options[:resource].pluralize.humanize
  end
    
  # add a form button
  # this was a merge conflict at a certain point, may need checking.
  def add_form_button(buttonspec)
    self.form_buttons << buttonspec
  end
    
  private
  
  def resource_model
    Object.const_get options[:resource].classify
  end
  
  # set_record sets the record object to that with the passed id.
  # If id is nil, record object is a new record, if parent id is set, it is passed to @where
  def set_record(id = nil, pid = nil)
    unless id.to_i > 0 && self.record = resource_model.includes(includes).find(id.to_i)
      self.record = resource_model.where((pid && where) ? where.call(pid) : {}).new
    end
  end
  
  # Called by after_initialize, will set the defaults prior to executing the configuration block.
  # options can include :resource and :form_only, both need to be known by this point.
  def setup(*)
    self.where = nil
    self.dom_id = options[:resource]
    self.grid_options = {}
    # Guesses that you will use the resource name for the form template.
    self.form_template = options[:resource]
    # The orphan template is used when a parent record is needed but not selected
    self.orphan_template = 'orphan'
    # Ensure that we always have a record of some sort
    self.record = resource_model.new
    
    @columns = []
    @sortable_columns = {}
    @default_sort = nil    

    @filters = {}
    @filter_sequence = []
    @filter_default = {}
    
    if options[:form_only]
      @list_widget = nil
      @filters_widget = nil
      self.form_buttons = [
        ['remain', 'Save', 'Add'],
      ]
    else
      @list_widget = options[:resource] + '_list'
      @filters_widget = options[:resource] + '_filters'
      self << widget(:grid_list, @list_widget) do |lw|
        lw << widget(:grid_filters, @filters_widget)
      end
      # self << (widget(:grid_list, @list_widget) << widget(:grid_filters, @filters_widget))
      self.form_buttons = [
        ['submit', 'Save+Close', 'Add+Close'],
        ['remain', 'Save', 'Add'],
        ['cancel', 'Cancel', 'Cancel'],
      ]
    end
  end
end
