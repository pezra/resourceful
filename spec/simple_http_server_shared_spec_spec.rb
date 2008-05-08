
describe 'http server' do
  it_should_behave_like 'simple http server'

  it 'should have a response code of whatever the path is' do
    pending
    Resourceful::NetHttpAdapter.get('http://localhost:3000/304')[0].should == 304
  end

  it 'should have a response code of 200 if the path is /get' do
    Resourceful::NetHttpAdapter.get('http://localhost:3000/get')[0].should == 200
  end

  it 'should reply with the posted document in the body if the path is /post' do
    Resourceful::NetHttpAdapter.post('http://localhost:3000/post')[2].should == 'Hello from POST!'
  end
end

