require 'odbc'
require 'slim'
require 'csv'
require 'date'
require 'fileutils'
require 'launchy'


HTML_OUT = File.join('output', 'index.html').freeze


# An inventory item / sold product.
Item = Struct.new(:id, :description, :category, :price)


# TODO: make this generic again
def read_table(table_name)
  ODBC.connect('', '', '') do |db|
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

# Reads a list of included item numbers from a file, and returns a filtered
# list of Item objects.
def fetch_produce_items
  all_items = read_table('SRCFILE')
  included_ids = File.readlines(File.join('data', 'included.txt')).map(&:chomp)

  @items = all_items.select do |i|
    included_ids.include?(i.id)
  end
end

# Sets the price attribute for each Item object, after reading the
# prices from a file.
def set_prices
  prices = CSV.readlines(File.join('data', 'prices.csv')).to_h
  prices.transform_values! do |val|
    val.strip.to_f
  end

  @items.each do |i|
    i.price = prices[i.id]
  end
end

# Sets the category attribute for each Item object, after reading the
# category names from a file.
def set_categories
  csv = CSV.readlines(File.join('data', 'categories.csv'))
  @categories = csv.each_with_object({}) do |(key, val), hsh|
    hsh[key] = val
  end

  @items.each do |i|
    i.category = @categories[i.category]
  end
end

# Copies static files needed for site to the output dir.
def copy_assets
  FileUtils.cd('view') do
    %w[style.css napoli.png ferraro.svg].each do |name|
      FileUtils.cp(name, File.join('..', 'output', name))
    end
  end
end

# Returns the date of the next day of the week, given the name of the day.
def date_of_next(day)
  date  = Date.parse(day)
  delta = date > Date.today ? 0 : 7
  date + delta
end

# Returns the slim template.
def template
  Slim::Template.new(File.join('view', 'index.html.slim'))
end

# Makes the index.html file.
def build_html
  fetch_produce_items
  set_prices
  set_categories

  @monday = date_of_next('Monday')
  @grouped_items = @items.group_by(&:category)

  File.open(HTML_OUT, 'wb') do |f|
    f << template.render(self)
  end
end

build_html
copy_assets
Launchy.open(HTML_OUT)
