# GridFormWidget is the widget that contains the editing panel/form.

class GridFormWidget < Apotomo::Widget
  include GridWidget::Controller
  include AppSupport::Controller
  helper GridWidget::Helper
  helper AppSupport::Helper

  after_add do |me, parent|
    # record selected on the list will bubble to parent and trigger record_selected here
    parent.respond_to_event :recordSelected, :with => :reveal_form, :on => me.name
    parent.respond_to_event :editRecord, :with => :edit_record, :on => me.name
    parent.respond_to_event :formSubmit, :with => :form_submitted, :on => me.name
    parent.respond_to_event :deleteRecord, :with => :delete_record, :on => me.name
    # I was under the impression apotomo set this for me, but yet I couldn't find it.
    @parent = parent
    @resource = parent.resource
    @container = parent.name
  end
  
  def display
    fetch_record
    update :view => 'form/' + @parent.form_template, :layout => 'form_wrapper'
  end
  
  # catch the record selected event, originates from the list.
  def reveal_form
    # Make a new form div so we can slide away the old one and swap ids
    # (This all relies on the id of the form corresponding to an enclosing div, incidentally)
    clone_form = <<-JS
    $('##{self.name}').clone().hide().css('background-color','#DDDDFF').attr('id','new_#{self.name}').insertAfter('##{self.name}');
    $('##{self.name}').attr('id', 'ex_#{self.name}');
    $('#new_#{self.name}').attr('id', '#{self.name}');
    JS
    # slide in the new one and slide out and destroy the old one
    swap_display = <<-JS
    $('##{self.name}').slideDown('fast');
    $('#ex_#{self.name}').slideUp('fast', function() { $(this).remove();});
    JS
    # This is kind of an internal use of a state, but, you know, it works.
    render :text => clone_form + self.display + ';' + swap_display
  end

  def form_submitted
    # TODO: Check. This might be a bit insecure at the moment 
    if param(:form_action) == 'submit'
      fetch_record
      @record.update_attributes(param(:record))
      @record.save
      # Tell the list to redraw
      trigger :recordUpdated
      render :text => turn_and_deveal_form
    else
      render :text => turn_and_deveal_form('#FF8888')
    end
  end
  
  def turn_and_deveal_form(color = '#88FF88')
    <<-JS
    $('##{self.name}').css('background-color','#{color}').slideUp('fast');
    $('##{self.name}').slideUp('fast');
    JS
  end

  def delete_record
    fetch_record
    @record.destroy
    trigger :recordUpdated
    render :text => turn_and_deveal_form('#FF8888')
  end
  
  # edit in place.  Right now, use only for toggles.
  # If you edit in place, it will cancel the form if it is open.
  # Later someday maybe I can make it reload or modify the form if the id matches.
  def edit_record
    c = @parent.columns[param(:col).to_i]
    if c[:inplace_edit]
      fetch_record
      if c[:toggle]
        f = c[:field]
        v = @record.send(f)
        @record.update_attributes({f => !v})
      end
      @record.save
      trigger :recordUpdated
      render :text => turn_and_deveal_form('#FF8888')
    else
      render :nothing => true
    end
  end
  
  private
  
  def fetch_record
    if param(:id).to_i > 0
      @record = (Object.const_get @resource.classify).includes(@parent.includes).find(param(:id))
    else
      @record = (Object.const_get @resource.classify).new
    end
  end
  
end
