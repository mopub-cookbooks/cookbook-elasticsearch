maintainer       "Scott M. Likens"
maintainer_email "scott@mopub.com"
license          "Apache"
description      "Installs and configures elasticsearch"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.markdown'))
version          "0.2.10"
name             "elasticsearch"

depends 'java'
depends 'runit'
recommends 'build-essential'
recommends 'xml'
recommends 'java'

provides 'elasticsearch'
provides 'elasticsearch::data'
provides 'elasticsearch::ebs'
provides 'elasticsearch::aws'
provides 'elasticsearch::nginx'
provides 'elasticsearch::proxy'
provides 'elasticsearch::plugins'
provides 'elasticsearch::monit'
