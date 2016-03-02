require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Command::Generator do
    describe 'CLAide' do
      it 'registers it self' do
        Command.parse(%w{ generator }).should.be.instance_of Command::Generator
      end
    end
  end
end

