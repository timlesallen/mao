require 'nao'

def relative_to_spec(filename)
  File.join(File.dirname(File.absolute_path(__FILE__)),
            filename)
end
