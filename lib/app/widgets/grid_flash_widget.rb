class GridFlashWidget < Apotomo::Widget

  # A :flash event will be posted by the parent (grid_edit) to be handled here.
  after_add do |me, mom|
    mom.respond_to_event :flash, :on => self.name, :from => parent.name
  end
  
  # display
  def display
    render :inline => '', :layout => 'flash_wrapper.html.erb'
  end

  # flash updates the contents
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
