class Hash
  def stringify_keys
    inject({}) do |options, (key, value)|
      options[key.to_s] = value
      options
    end
  end
  def stringify_keys!
   keys.each do |key|
     self[key.to_s] = delete(key)
   end
   self
  end
end
