# This file is autogenerated. Instead of editing this file, please use the
# migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.

ActiveRecord::Schema.define(:version => 3) do

  create_table "products", :force => true do |t|
    t.column "vending_machine_id", :integer
    t.column "name",               :string
    t.column "price",              :integer
    t.column "inventory",          :integer
    t.column "position",           :integer
  end

  create_table "vending_machines", :force => true do |t|
    t.column "location", :string
    t.column "cash",     :integer
  end

end
