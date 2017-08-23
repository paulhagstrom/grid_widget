GridWidget
==========

This uses apotomo/cells to create a grid/form editing system using jqgrid.

This was a vendor/plugin for Rails 3.2 but I need to move it to a gem.
This is kind of rushed but I am hoping I can tidy it up a little bit.

My rdoc-ization is although kind of weak, but I expect it will be improved.  You're looking at this at a pretty
early stage in the development.

No tests yet either.  I know.

NOTE

I used to have an installation procedure that would package jQuery, jQuery-UI, jquery-ujs, and jqgrid.
But that's dumb.  Those should be updated individually.

So, include these in public/javascripts and public/stylesheets, or wherever you put those things:

jQuery:
jquery.min.js
originally was 1.4.4

jquery-ui:
jquery-ui.min.js
images/
originally was 1.8.7

jQGrid:
jquery.jqGrid.min.js
grid.locale-en.js
ui.jqgrid.css
originally was 3.8

jquery-ujs:
rails.js
originaly one that says it supports 1.4.3 and 1.4.4

And then copy gridwidget.css into the stylesheets path as well.  That can be done with

rails generate grid_wiget:install 


Example
=======

Example goes here.  Eventually.

Below it says 2011.  But it is now 2017.  Nice.

Copyright (c) 2011 Paul Hagstrom, released under the MIT license
