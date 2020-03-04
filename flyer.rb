require 'odbc'
require 'slim'
require 'csv'
require 'date'
require 'fileutils'
require 'launchy'

Item = Struct.new(:id, :description, :category, :price)

def date_of_next(day)
  date  = Date.parse(day)
  delta = date > Date.today ? 0 : 7
  date + delta
end

def read_table(table_name)
  ODBC::connect('','','') do |db|
    rows = db.run("select * from #{table_name}").each_hash

    rows.map do |row|
      row.transform_values!(&:strip)
      id = row['FFJITMN']
      desc = row['FFIIDE1'].sub(/^PRODX?/, '').strip
      cat = row['FFJPBHN']

      Item.new(id, desc, cat, nil)
    end
  end
end

def main
  # load items
  @all_items = read_table('SRCFILE')

  # filter items
  @included_ids = File.readlines(File.join('data', 'included.txt')).map(&:chomp)
  @items = @all_items.select { |i| @included_ids.include?(i.id) }

  # fill prices
  @prices = CSV.readlines(File.join('data', 'prices.csv')).to_h
  @prices.transform_values! do |val|
    val.strip.to_f
  end
  @items.each { |i| i.price = @prices[i.id] }

  # fill categories
  @categories = CSV.readlines(File.join('data', 'categories.csv')).each_with_object({}) do |(key, val), hsh|
    hsh[key] = val
  end
  @items.each { |i| i.category = @categories[i.category] }

  @monday = date_of_next('Monday')
  @grouped_items = @items.group_by(&:category)

  # make html
  template = Slim::Template.new(File.join('view', 'index.html.slim'))
  outfile_name = File.join('output', 'index.html')
  File.open(outfile_name, 'wb') do |file|
    file << template.render(self)
  end
  template.render(self)

  # copy stylesheet
  FileUtils.cp(File.join('view', 'style.css'), File.join('output', 'style.css'))
  FileUtils.cp(File.join('view', 'napoli.png'), File.join('output', 'napoli.png'))
  FileUtils.cp(File.join('view', 'ferraro.svg'), File.join('output', 'ferraro.svg'))

  Launchy.open(outfile_name)
end

main
