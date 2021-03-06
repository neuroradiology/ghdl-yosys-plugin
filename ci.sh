#!/bin/sh

set -e

cd "$(dirname $0)"
. ./utils.sh

# To build latest GHDL from sources, uncomment the following block
# and replace --from=ghdl/pkg:buster-mcode below with --from=tmp

#docker build -t tmp - <<-EOF
#FROM ghdl/build:buster-mcode
#RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
#    ca-certificates curl && update-ca-certificates \
# && mkdir -p ghdl && cd ghdl \
# && curl -fsSL "$GHDL_URL" | tar xzf - --strip-components=1 \
# && ./configure --enable-libghdl --enable-synth \
# && make all \
# && make DESTDIR=/opt/ghdl install
#EOF

#--

gstart "[Build] ghdl/synth:beta" "$ANSI_MAGENTA"

docker build -t ghdl/synth:beta . -f- <<-EOF
FROM ghdl/cache:yosys-gnat AS build
COPY --from=ghdl/pkg:buster-mcode / /opt/ghdl
COPY . /ghdlsynth

RUN cp -vr /opt/ghdl/* /usr/local \
 && cd /ghdlsynth \
 && make \
 && cp ghdl.so /opt/ghdl/lib/ghdl_yosys.so

FROM ghdl/cache:yosys-gnat
COPY --from=build /opt/ghdl /usr/local
RUN yosys-config --exec mkdir -p --datdir/plugins \
 && yosys-config --exec ln -s /usr/local/lib/ghdl_yosys.so --datdir/plugins/ghdl.so
EOF

gend

#---

gstart "[Build] ghdl/synth:formal" "$ANSI_MAGENTA"
docker build -t ghdl/synth:formal --build-arg IMAGE='ghdl/synth:beta' . -f- <<-EOF
$(curl -fsSL https://github.com/ghdl/docker/raw/master/dockerfiles/synth_formal)
EOF
gend "formal"

#---

printf "${ANSI_MAGENTA}[Test] testsuite ${ANSI_NOCOLOR}\n"

docker run --rm -t -e CI -v /$(pwd)://src -w //src -e YOSYS='yosys -m ghdl' ghdl/synth:formal bash -c "$(cat <<EOF
./testsuite/testsuite.sh
EOF
)"
