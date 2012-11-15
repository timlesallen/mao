require 'mao'

def relative_to_spec(filename)
  File.join(File.dirname(File.absolute_path(__FILE__)),
            filename)
end

def prepare_spec
  `psql mao_testing -f #{relative_to_spec("fixture.sql")} 2>&1 | grep -v ^NOTICE`
  Mao.connect!(:dbname => 'mao_testing')
end

# vim: set sw=2 cc=80 et:
