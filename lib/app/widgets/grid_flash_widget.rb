class GridFlashWidget < Apotomo::Widget

  # A :flash event will be posted by the parent (grid_edit) to be handled here.
  # Updated for apotomo 1.2 (changed to after_initialize from after_add)
  after_initialize do |me|
    me.parent.respond_to_event :flash, :on => me.name, :from => me.parent.name
    me.parent.respond_to_event :flash_deveal, :on => me.name, :from => me.parent.name
  end
  
  # display
  def display
    render :inline => '', :layout => 'flash_wrapper.html.erb'
  end

  # hide
  def flash_deveal
    render :view => 'flash_deveal.js.erb', :locals => {:flashid => "#{dom_id}_flash"}
  end

  # flash reveals and updates the contents of the flash box
  def flash(evt = nil)
    @notice = evt[:notice] rescue ''
    @alert = evt[:alert] rescue ''
    render :text => update("##{dom_id}_flash"), :layout => 'flash_effect.js.erb',
      :locals => {:flashid => "#{dom_id}_flash"}
  end
  
  private 
    
  def dom_id
    parent.dom_id
  end
    
  public :dom_id  # view needs to be able to see this
  
end
