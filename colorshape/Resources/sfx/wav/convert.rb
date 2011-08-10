#!/usr/bin/env ruby

wavs = `ls *.wav`

wavs.each { |wav| 
  base = `basename -s .wav #{wav}`.strip!
  caf = "../caf/#{base}.caf"
  wav.strip!
  
  `afconvert -f caff -d LEI16@22050 -c 1 #{wav} #{caf}`
}