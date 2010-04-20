require 'tmpdir'
require 'spec'
context "file writing" do
  it "writes to a file" do
    File.open(File.join(Dir.tmpdir, 'hydra_test.txt'), 'a') do |f|
      f.write "HYDRA"
    end
  end
  it 'could do so much more'  # pending spec
end

