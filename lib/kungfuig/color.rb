module Kungfuig
  # Dealing with colors
  class Color

    # Copyright (c) 2007 McClain Looney
    #
    # Permission is hereby granted, free of charge, to any person obtaining a copy
    # of this software and associated documentation files (the "Software"), to deal
    # in the Software without restriction, including without limitation the rights
    # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    # copies of the Software, and to permit persons to whom the Software is
    # furnished to do so, subject to the following conditions:
    #
    # The above copyright notice and this permission notice shall be included in
    # all copies or substantial portions of the Software.
    #
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    # LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    # THE SOFTWARE.

    # Implements a color (r,g,b + a) with conversion to/from web format (eg #aabbcc), and
    # with a number of utilities to lighten, darken and blend values.

    attr_reader :r, :g, :b, :a

    # Table for conversion to hex
    HEXVAL = ('0'..'9').to_a.concat(('A'..'F').to_a).freeze
    # Default value for #darken, #lighten etc.
    BRIGHTNESS_DEFAULT = 0.2

    # Constructor.  Inits to white (#FFFFFF) by default, or accepts any params
    # supported by #parse.
    def initialize(*args)
      @r = 255
      @g = 255
      @b = 255
      @a = 255

      if args.size.between?(3, 4)
        self.r = args[0]
        self.g = args[1]
        self.b = args[2]
        self.a = args[3] if args[3]
      else
        set(*args)
      end
    end

    # All-purpose setter - pass in another Color, '#000000', rgb vals... whatever
    def set(*args)
      val = Color.parse(*args)
      unless val.nil?
        self.r = val.r
        self.g = val.g
        self.b = val.b
        self.a = val.a
      end
      self
    end

    # Test for equality, accepts string vals as well, eg Color.new('aaa') == '#AAAAAA' => true
    def ==(other)
      val = Color.parse(other)
      return false if val.nil?
      r == val.r && g == val.g && b == val.b && a == val.a
    end

    # Setters for individual channels - take 0-255 or '00'-'FF' values
    %i(r g b a).each do |m|
      define_method "#{m}=" do |val|
        instance_variable_set("@#{m}", from_hex(val))
      end
    end

    # Attempt to read in a string and parse it into values
    def self.parse(*args)
      case args.size
      when 0 then return nil
      when 1
        case val = args.first
        when Color then val
        when Fixnum then Color.new(val, val, val) # Single value, assume grayscale
        when String
          str = val.to_s.upcase[/[0-9A-F]{3,8}/] || ''
          Color.new(*case str.size
                     when 3, 4 then str.scan(/[0-9A-F]/)
                     when 6, 8 then str.scan(/[0-9A-F]{2}/)
                     else 'FF'
                     end.map { |c| Integer("0x#{c}") })
        end
      when 2 # assume gray + alpha
        val, alpha = args
        Color.new(val, val, val, alpha)
      when 3, 4 then Color.new(*args)
      end
    end

    def inspect
      id = format('%x', object_id << 1)
      "#<#{self.class.name}:0x#{id.rjust(14, '0')} 💻=“\\e[#{to_esc(true)}#{to_esc(false)}\e[0mm” 🗔=“#{self}”>"
    end

    def to_s(add_hash = true)
      trans? ? to_rgba(add_hash) : to_rgb(add_hash)
    end

    # Color as used in 256-color terminal escape sequences
    def to_esc(surround = true, bold: true, italic: false, underline: false, reverse: false, foreground: true)
      result = if grayscale?
                 (r > 239) ? 15 : (r / 10).floor + 232
               else
                 16 + 36 * (r / 51).floor + 6 * (g / 51).floor + (b / 51).floor
               end

      esc = [
        bold ? '01' : nil,
        italic ? '03' : nil,
        underline ? '04' : nil,
        reverse ? '07' : nil,
        foreground ? '38' : '48',
        '05',
        result
      ].compact.join(';')

      surround ? "\e[#{esc}m" : esc
    end

    def to_rgb(add_hash = true)
      (add_hash ? '#' : '') + to_hex(r) + to_hex(g) + to_hex(b)
    end

    def to_rgba(add_hash = true)
      to_rgb(add_hash) + to_hex(a)
    end

    def opaque?
      @a == 255
    end

    def trans?
      !opaque?
    end

    def grayscale?
      @r == @g && @g == @b
    end

    # Lighten color towards white.  0.0 is a no-op, 1.0 will return #FFFFFF
    def lighten(amt = BRIGHTNESS_DEFAULT)
      return self if amt <= 0
      return WHITE if amt >= 1.0
      Color.new(self).tap do |val|
        val.r += ((255 - val.r) * amt).to_i
        val.g += ((255 - val.g) * amt).to_i
        val.b += ((255 - val.b) * amt).to_i
      end
    end

    # In place version of #lighten
    def lighten!(amt = BRIGHTNESS_DEFAULT)
      set(lighten(amt))
    end

    # Darken a color towards full black.  0.0 is a no-op, 1.0 will return #000000
    def darken(amt = BRIGHTNESS_DEFAULT)
      return self if amt <= 0
      return BLACK if amt >= 1.0
      Color.new(self).tap do |val|
        val.r -= (val.r * amt).to_i
        val.g -= (val.g * amt).to_i
        val.b -= (val.b * amt).to_i
      end
    end

    # In place version of #darken
    def darken!(amt = BRIGHTNESS_DEFAULT)
      set(darken(amt))
    end

    # Convert to grayscale, using perception-based weighting
    def grayscale
      Color.new(self).tap do |val|
        val.r = val.g = val.b = (0.2126 * val.r + 0.7152 * val.g + 0.0722 * val.b)
      end
    end

    # In place version of #grayscale
    def grayscale!
      set(grayscale)
    end

    # Blend to a color amt % towards another color value, eg
    # red.blend(blue, 0.5) will be purple, white.blend(black, 0.5) will be gray, etc.
    def blend(other, amt)
      other = Color.parse(other)
      return Color.new(self) if amt <= 0 || other.nil?
      return Color.new(other) if amt >= 1.0
      Color.new(self).tap do |val|
        val.r += ((other.r - val.r) * amt).to_i
        val.g += ((other.g - val.g) * amt).to_i
        val.b += ((other.b - val.b) * amt).to_i
      end
    end

    # In place version of #blend
    def blend!(other, amt)
      set(blend(other, amt))
      self
    end

    # Class-level version for explicit blends of two values, useful with constants
    def self.blend(col1, col2, amt)
      col1, col2 = [col1, col2].map { |c| Color.parse c }
      col1.blend(col2, amt)
    end

    def self.to_xterm256(text, color, bold: true, italic: false, underline: false, reverse: false, foreground: true)
      color = Color.preset(color) unless color.is_a?(Color)
      [
        color.to_esc(true, bold: bold, italic: italic, underline: underline, reverse: reverse, foreground: foreground),
        text,
        "\e[0m"
      ].join
    end

    def self.preset type
      Color.parse case type
                  when :label then '#999999'
                  when :success then '#468847'
                  when :warning then '#F89406'
                  when :important then '#B94A48'
                  when :fatal then '#B94A48'
                  when :error then '#FF0000'
                  when :info then '#3A87AD'
                  when :inverse then '#333333'
                  else type
                  end
    end

    protected

    # Convert int to string hex, eg 255 => 'FF'
    def to_hex(val)
      HEXVAL[val / 16] + HEXVAL[val % 16]
    end

    # Convert int or string to int, eg 80 => 80, 'FF' => 255, '7' => 119
    def from_hex(val)
      if val.is_a?(String)
        # Double up if single char form
        val = val + val if val.size == 1
        # Convert to integer
        val = val.hex
      end
      # Clamp
      val = 0 if val < 0
      val = 255 if val > 255
      val
    end

    public

    # Some constants for general use
    WHITE = Color.new(255, 255, 255).freeze
    BLACK = Color.new(0, 0, 0).freeze
  end
end
