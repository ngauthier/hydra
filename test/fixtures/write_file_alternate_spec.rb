require 'rspec'
require 'hydra/tmpdir'
context "file writing" do
  it "writes to a file" do
    File.open(File.join(Dir.consistent_tmpdir, 'alternate_hydra_test.txt'), 'a') do |f|
      f.write "HYDRA"
    end
  end
end

