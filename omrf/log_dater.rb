module OMRF
  module LogDater
    def log(type,msg)
      super(type,"#{Time.now.utc}: #{msg}")
    end
  end
end
