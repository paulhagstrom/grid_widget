# These are the predefined custom display methods (invoked by column displays in the grid)
# and set using the :custom parameter on a column.
module GridWidget
  module CustomDisplayMethods

    # Custom display method to abbreviate a long string
    def custom_abbrev(long_string)
      long_string[0..20] + (long_string.size > 10 ? '...' : '') rescue ''
    end

    # Custom display method for booleans: Yes if true, otherwise no
    def custom_yn(value)
      value ? 'YES' : 'No'
    end

    # Custom display method for booleans: check if true, otherwise nothing, using jQuery UI
    def custom_check(value)
      value ? '<span class="ui-icon ui-icon-check"></span>' : ''
    end

  end
end
