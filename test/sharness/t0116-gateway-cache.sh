#!/usr/bin/env bash

test_description="Test HTTP Gateway Cache Control Support"

. lib/test-lib.sh

test_init_ipfs
test_launch_ipfs_daemon_without_network

# Cache control support is based on logical roots (each path segment == one logical root).
# To maximize the test surface, we want to test:
# - /ipfs/ content path
# - /ipns/ content path
# - at least 3 levels
# - separate tests for a directory listing and a file
# - have implicit index.html for a good measure
# /ipns/root1/root2/root3/ (/ipns/root1/root2/root3/index.html)

# Note: we cover important UnixFS-focused edge case here:
#
# ROOT3_CID - dir listing (dir-index-html response)
# ROOT4_CID - index.html returned as a root response (dir/), instead of generated dir-index-html
# FILE_CID  - index.html returned directly, as a file
#
# Caching of things like raw blocks, CARs, dag-json and dag-cbor
# is tested in their respective suites.

ROOT1_CID=bafybeib3ffl2teiqdncv3mkz4r23b5ctrwkzrrhctdbne6iboayxuxk5ui # ./
ROOT2_CID=bafybeih2w7hjocxjg6g2ku25hvmd53zj7og4txpby3vsusfefw5rrg5sii # ./root2
ROOT3_CID=bafybeiawdvhmjcz65x5egzx4iukxc72hg4woks6v6fvgyupiyt3oczk5ja # ./root2/root3
ROOT4_CID=bafybeifq2rzpqnqrsdupncmkmhs3ckxxjhuvdcbvydkgvch3ms24k5lo7q # ./root2/root3/root4
FILE_CID=bafkreicysg23kiwv34eg2d7qweipxwosdo2py4ldv42nbauguluen5v6am # ./root2/root3/root4/index.html
TEST_IPNS_ID=k51qzi5uqu5dlxdsdu5fpuu7h69wu4ohp32iwm9pdt9nq3y5rpn3ln9j12zfhe

# Import test case
# See the static fixtures in ./t0116-gateway-cache/
test_expect_success "Add the test directory" '
  ipfs dag import --pin-roots ../t0116-gateway-cache/fixtures.car
  ipfs routing put --allow-offline /ipns/${TEST_IPNS_ID} ../t0116-gateway-cache/${TEST_IPNS_ID}.ipns-record
'

# GET /ipfs/
    # unixfs
    test_expect_success "GET for /ipfs/ unixfs dir listing succeeds" '
    curl -svX GET "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/" >/dev/null 2>curl_ipfs_dir_listing_output
    '
    test_expect_success "GET for /ipfs/ unixfs dir with index.html succeeds" '
    curl -svX GET "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/root4/" >/dev/null 2>curl_ipfs_dir_index.html_output
    '
    test_expect_success "GET for /ipfs/ unixfs file succeeds" '
    curl -svX GET "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/root4/index.html" >/dev/null 2>curl_ipfs_file_output
    '
    # unixfs dir as dag-json
    test_expect_success "GET for /ipfs/ unixfs dir as DAG-JSON succeeds" '
    curl -svX GET "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/root4/?format=dag-json" >/dev/null 2>curl_ipfs_dir_dag-json_output &&
    curl -svX GET "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/root4/?format=json" >/dev/null 2>curl_ipfs_dir_json_output
    '
# GET /ipns/
    # unixfs
    test_expect_success "GET for /ipns/ unixfs dir listing succeeds" '
    curl -svX GET "http://127.0.0.1:$GWAY_PORT/ipns/$TEST_IPNS_ID/root2/root3/" >/dev/null 2>curl_ipns_dir_listing_output
    '
    test_expect_success "GET for /ipns/ unixfs dir with index.html succeeds" '
    curl -svX GET "http://127.0.0.1:$GWAY_PORT/ipns/$TEST_IPNS_ID/root2/root3/root4/" >/dev/null 2>curl_ipns_dir_index.html_output
    '
    test_expect_success "GET for /ipns/ unixfs file succeeds" '
    curl -svX GET "http://127.0.0.1:$GWAY_PORT/ipns/$TEST_IPNS_ID/root2/root3/root4/index.html" >/dev/null 2>curl_ipns_file_output
    '
    # unixfs dir as dag-json
    test_expect_success "GET for /ipns/ unixfs dir as DAG-JSON succeeds" '
    curl -svX GET "http://127.0.0.1:$GWAY_PORT/ipns/$TEST_IPNS_ID/root2/root3/root4/?format=dag-json" >/dev/null 2>curl_ipns_dir_dag-json_output &&
    curl -svX GET "http://127.0.0.1:$GWAY_PORT/ipns/$TEST_IPNS_ID/root2/root3/root4/?format=json" >/dev/null 2>curl_ipns_dir_json_output
    '

# Cache-Control

# Cache-Control: immutable /ipfs/ file
    test_expect_success "GET /ipfs/ unixfs file has expected Cache-Control" '
    test_should_contain "< Cache-Control: public, max-age=29030400, immutable" curl_ipfs_file_output
    '
# Cache-Control: generated /ipfs/dir/ (listing)
    # TODO: test_should_contain "< Cache-Control: public, max-age=TBD" curl_ipfs_dir_listing_output
    test_expect_success "GET /ipfs/ unixfs dir listing has no Cache-Control" '
    test_should_not_contain "< Cache-Control" curl_ipns_dir_listing_output
    '
# Cache-Control: immutable /ipfs/dir/ (index.html)
    test_expect_success "GET /ipfs/ unixfs dir with index.html has expected Cache-Control" '
    test_should_contain "< Cache-Control: public, max-age=29030400, immutable" curl_ipfs_dir_index.html_output
    '
# Cache-Control: immutable /ipfs/ unixfs dir as dag-json
    test_expect_success "GET /ipfs/ dag-json has expected Cache-Control" '
    test_should_contain "< Cache-Control: public, max-age=29030400, immutable" curl_ipfs_dir_dag-json_output
    '
# Cache-Control: immutable /ipfs/ unixfs dir as json
    test_expect_success "GET /ipfs/ unixfs dir as json has expected Cache-Control" '
    test_should_contain "< Cache-Control: public, max-age=29030400, immutable" curl_ipfs_dir_json_output
    '
# Cache-Control: mutable /ipns/ file
    test_expect_success "GET /ipns/ unixfs file has no Cache-Control" '
    test_should_not_contain "< Cache-Control" curl_ipns_file_output
    '
# Cache-Control: mutable /ipns/dir/ (generated listing)
    test_expect_success "GET /ipns/ unixfs dir listing has no Cache-Control" '
    test_should_not_contain "< Cache-Control" curl_ipns_dir_listing_output
    '
# Cache-Control: mutable /ipns/dir/ (index.html)
    test_expect_success "GET /ipns/ unixfs dir with index.html has no Cache-Control" '
    test_should_not_contain "< Cache-Control" curl_ipns_dir_index.html_output
    '
# Cache-Control: mutable /ipns/dir/ as dag-json
    test_expect_success "GET /ipns/ unixfs dir as dag-json has no Cache-Control" '
    test_should_not_contain "< Cache-Control" curl_ipns_dir_dag-json_output
    '
# Cache-Control: mutable /ipns/dir/ as json
    test_expect_success "GET /ipns/ unixfs dir as json has no Cache-Control" '
    test_should_not_contain "< Cache-Control" curl_ipns_dir_json_output
    '

# Cache-Control: only-if-cached
    test_expect_success "HEAD for /ipfs/ with only-if-cached succeeds when in local datastore" '
    curl -sv -I -H "Cache-Control: only-if-cached" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/root4/index.html" > curl_onlyifcached_postitive_head 2>&1 &&
    cat curl_onlyifcached_postitive_head &&
    grep "< HTTP/1.1 200 OK" curl_onlyifcached_postitive_head
    '
    test_expect_success "HEAD for /ipfs/ with only-if-cached fails when not in local datastore" '
    curl -sv -I -H "Cache-Control: only-if-cached" "http://127.0.0.1:$GWAY_PORT/ipfs/$(date | ipfs add --only-hash -Q)" > curl_onlyifcached_negative_head 2>&1 &&
    cat curl_onlyifcached_negative_head &&
    grep "< HTTP/1.1 412 Precondition Failed" curl_onlyifcached_negative_head
    '
    test_expect_success "GET for /ipfs/ with only-if-cached succeeds when in local datastore" '
    curl -svX GET -H "Cache-Control: only-if-cached" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/root4/index.html" >/dev/null 2>curl_onlyifcached_postitive_out &&
    cat curl_onlyifcached_postitive_out &&
    grep "< HTTP/1.1 200 OK" curl_onlyifcached_postitive_out
    '
    test_expect_success "GET for /ipfs/ with only-if-cached fails when not in local datastore" '
    curl -svX GET -H "Cache-Control: only-if-cached" "http://127.0.0.1:$GWAY_PORT/ipfs/$(date | ipfs add --only-hash -Q)" >/dev/null 2>curl_onlyifcached_negative_out &&
    cat curl_onlyifcached_negative_out &&
    grep "< HTTP/1.1 412 Precondition Failed" curl_onlyifcached_negative_out
    '

# X-Ipfs-Path

    ## dir generated listing
    test_expect_success "GET /ipfs/ dir listing response has original content path in X-Ipfs-Path" '
    test_should_contain "< X-Ipfs-Path: /ipfs/$ROOT1_CID/root2/root3" curl_ipfs_dir_listing_output
    '
    test_expect_success "GET /ipns/ dir listing response has original content path in X-Ipfs-Path" '
    test_should_contain "< X-Ipfs-Path: /ipns/$TEST_IPNS_ID/root2/root3" curl_ipns_dir_listing_output
    '

    ## dir static index.html
    test_expect_success "GET /ipfs/ dir index.html response has original content path in X-Ipfs-Path" '
    test_should_contain "< X-Ipfs-Path: /ipfs/$ROOT1_CID/root2/root3/root4/" curl_ipfs_dir_index.html_output
    '
    test_expect_success "GET /ipns/ dir index.html response has original content path in X-Ipfs-Path" '
    test_should_contain "< X-Ipfs-Path: /ipns/$TEST_IPNS_ID/root2/root3/root4/" curl_ipns_dir_index.html_output
    '

    # file
    test_expect_success "GET /ipfs/ file response has original content path in X-Ipfs-Path" '
    test_should_contain "< X-Ipfs-Path: /ipfs/$ROOT1_CID/root2/root3/root4/index.html" curl_ipfs_file_output
    '
    test_expect_success "GET /ipns/ file response has original content path in X-Ipfs-Path" '
    test_should_contain "< X-Ipfs-Path: /ipns/$TEST_IPNS_ID/root2/root3/root4/index.html" curl_ipns_file_output
    '

# X-Ipfs-Roots

    ## dir generated listing
    test_expect_success "GET /ipfs/ dir listing response has logical CID roots in X-Ipfs-Roots" '
    test_should_contain "< X-Ipfs-Roots: ${ROOT1_CID},${ROOT2_CID},${ROOT3_CID}" curl_ipfs_dir_listing_output
    '
    test_expect_success "GET /ipns/ dir listing response has logical CID roots in X-Ipfs-Roots" '
    test_should_contain "< X-Ipfs-Roots: ${ROOT1_CID},${ROOT2_CID},${ROOT3_CID}" curl_ipns_dir_listing_output
    '

    ## dir static index.html
    test_expect_success "GET /ipfs/ dir index.html response has logical CID roots in X-Ipfs-Roots" '
    test_should_contain "< X-Ipfs-Roots: ${ROOT1_CID},${ROOT2_CID},${ROOT3_CID},${ROOT4_CID}" curl_ipfs_dir_index.html_output
    '
    test_expect_success "GET /ipns/ dir index.html response has logical CID roots in X-Ipfs-Roots" '
    test_should_contain "< X-Ipfs-Roots: ${ROOT1_CID},${ROOT2_CID},${ROOT3_CID},${ROOT4_CID}" curl_ipns_dir_index.html_output
    '

    ## file
    test_expect_success "GET /ipfs/ file response has logical CID roots in X-Ipfs-Roots" '
    test_should_contain "< X-Ipfs-Roots: ${ROOT1_CID},${ROOT2_CID},${ROOT3_CID},${ROOT4_CID},${FILE_CID}" curl_ipfs_file_output
    '
    test_expect_success "GET /ipns/ file response has logical CID roots in X-Ipfs-Roots" '
    test_should_contain "< X-Ipfs-Roots: ${ROOT1_CID},${ROOT2_CID},${ROOT3_CID},${ROOT4_CID},${FILE_CID}" curl_ipns_file_output
    '

# Etag

    ## dir generated listing
    test_expect_success "GET /ipfs/ dir response has special Etag for generated dir listing" '
    test_should_contain "< Etag: \"DirIndex" curl_ipfs_dir_listing_output &&
    grep -E "< Etag: \"DirIndex-.+_CID-${ROOT3_CID}\"" curl_ipfs_dir_listing_output
    '
    test_expect_success "GET /ipns/ dir response has special Etag for generated dir listing" '
    test_should_contain "< Etag: \"DirIndex" curl_ipns_dir_listing_output &&
    grep -E "< Etag: \"DirIndex-.+_CID-${ROOT3_CID}\"" curl_ipns_dir_listing_output
    '

    ## dir static index.html should use CID of  the index.html file for improved HTTP caching
    test_expect_success "GET /ipfs/ dir index.html response has dir CID as Etag" '
    test_should_contain "< Etag: \"${ROOT4_CID}\"" curl_ipfs_dir_index.html_output
    '
    test_expect_success "GET /ipns/ dir index.html response has dir CID as Etag" '
    test_should_contain "< Etag: \"${ROOT4_CID}\"" curl_ipns_dir_index.html_output
    '

    ## file
    test_expect_success "GET /ipfs/ response has CID as Etag for a file" '
    test_should_contain "< Etag: \"${FILE_CID}\"" curl_ipfs_file_output
    '
    test_expect_success "GET /ipns/ response has CID as Etag for a file" '
    test_should_contain "< Etag: \"${FILE_CID}\"" curl_ipns_file_output
    '

# If-None-Match (return 304 Not Modified when client sends matching Etag they already have)

    test_expect_success "GET for /ipfs/ file with matching Etag in If-None-Match returns 304 Not Modified" '
    curl -svX GET -H "If-None-Match: \"$FILE_CID\"" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/root4/index.html" >/dev/null 2>curl_output &&
    test_should_contain "304 Not Modified" curl_output
    '

    test_expect_success "GET for /ipfs/ dir with index.html file with matching Etag in If-None-Match returns 304 Not Modified" '
    curl -svX GET -H "If-None-Match: \"$ROOT4_CID\"" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/root4/" >/dev/null 2>curl_output &&
    test_should_contain "304 Not Modified" curl_output
    '

    test_expect_success "GET for /ipfs/ file with matching third Etag in If-None-Match returns 304 Not Modified" '
    curl -svX GET -H "If-None-Match: \"fakeEtag1\", \"fakeEtag2\", \"$FILE_CID\"" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/root4/index.html" >/dev/null 2>curl_output &&
    test_should_contain "304 Not Modified" curl_output
    '

    test_expect_success "GET for /ipfs/ file with matching weak Etag in If-None-Match returns 304 Not Modified" '
    curl -svX GET -H "If-None-Match: W/\"$FILE_CID\"" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/root4/index.html" >/dev/null 2>curl_output &&
    test_should_contain "304 Not Modified" curl_output
    '

    test_expect_success "GET for /ipfs/ file with wildcard Etag in If-None-Match returns 304 Not Modified" '
    curl -svX GET -H "If-None-Match: *" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/root4/index.html" >/dev/null 2>curl_output &&
    test_should_contain "304 Not Modified" curl_output
    '

    test_expect_success "GET for /ipns/ file with matching Etag in If-None-Match returns 304 Not Modified" '
    curl -svX GET -H "If-None-Match: \"$FILE_CID\"" "http://127.0.0.1:$GWAY_PORT/ipns/$TEST_IPNS_ID/root2/root3/root4/index.html" >/dev/null 2>curl_output &&
    test_should_contain "304 Not Modified" curl_output
    '

    test_expect_success "GET for /ipfs/ dir listing with matching weak Etag in If-None-Match returns 304 Not Modified" '
    curl -svX GET -H "If-None-Match: W/\"$ROOT3_CID\"" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/" >/dev/null 2>curl_output &&
    test_should_contain "304 Not Modified" curl_output
    '

    # DirIndex etag is based on xxhash(./assets/dir-index-html), so we need to fetch it dynamically
    test_expect_success "GET for /ipfs/ dir listing with matching strong Etag in If-None-Match returns 304 Not Modified" '
    curl -Is "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/"| grep -i Etag | cut -f2- -d: | tr -d "[:space:]\"" > dir_index_etag &&
    curl -svX GET -H "If-None-Match: \"$(<dir_index_etag)\"" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/" >/dev/null 2>curl_output &&
    test_should_contain "304 Not Modified" curl_output
    '
    test_expect_success "GET for /ipfs/ dir listing with matching weak Etag in If-None-Match returns 304 Not Modified" '
    curl -Is "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/"| grep -i Etag | cut -f2- -d: | tr -d "[:space:]\"" > dir_index_etag &&
    curl -svX GET -H "If-None-Match: W/\"$(<dir_index_etag)\"" "http://127.0.0.1:$GWAY_PORT/ipfs/$ROOT1_CID/root2/root3/" >/dev/null 2>curl_output &&
    test_should_contain "304 Not Modified" curl_output
    '

test_kill_ipfs_daemon

test_done
