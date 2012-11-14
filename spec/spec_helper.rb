require 'norm'

def relative_to_spec(filename)
  File.join(File.dirname(File.absolute_path(__FILE__)),
            filename)
end

def prepare_spec
  `psql norm_testing -f #{relative_to_spec("fixture.sql")}`
  Norm.connect!(:dbname => 'norm_testing')
end

# vim: set sw=2 cc=80 et:
