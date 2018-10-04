#!/usr/bin/env bats

load test_helper

@test "show" {
	check () {
		git signatures show
		git signatures show HEAD
		git signatures show --raw
		git signatures show --raw HEAD
	}
	check # check it doesn't fail with no signatures
	git signatures add
	check # check it doesn't fail with a signature
}

@test "sign" {
	sign() {
		git signatures add $1
		git signatures add --key "Approver 1" $1
	}
	sign
	run git signatures show --raw
	[ $(wc -l <<< "$output") = 2 ]
	sign HEAD
	run git signatures show --raw
	[ $(wc -l <<< "$output") = 4 ]
}

@test "sign and push" {
	run git signatures add --push
	THIS=$(git rev-parse HEAD)
	cd $REPO_REMOTE
	run git signatures show --raw $THIS
	[ $(wc -l <<< "$output") = 1 ]
}

@test "invalid keys fail properly" {
	run git signatures add --key "INVALIDKEY"
	[ "$status" -eq 1 ]

	git config user.signingKey "INVALIDKEY"

	run git signatures add
	[ "$status" -eq 1 ]
}

@test "verify" {
	git signatures add
	git signatures verify --min-count=1
	run git signatures verify --min-count=2
	[ "$status" -eq 1 ]

	git signatures add --key "Approver 1"
	git signatures verify --min-count=2

	git signatures add --key "Approver 2"
	git signatures verify --min-count=3
}

@test "verify with an expired key" {
	PAST='faketime -f -2y'
	echo "### 2 years ago"
	$PAST gpg -k
	$PAST git signatures add --key "Expired 1"
	$PAST git signatures add --key "Approver 1"
	$PAST git signatures verify --min-count=2 || true

	echo "### now"
	git signatures verify --min-count=1
	run git signatures verify --min-count=2
	[ "$status" -eq 1 ]
}

@test "verify with a revoked key" {
	git signatures add --key "Approver 1"
	git signatures add --key "Approver 2"
	git signatures verify --min-count=2

	gpg --import "$FILES"/example.com/approver1.rev
	git signatures verify --min-count=1
	run git signatures verify --min-count=2
	[ "$status" -eq 1 ]
}

@test "verify with a unknown key" {
	(
		cd "$REPO_REMOTE"

		setup_gpg
		gpg --import "$FILES"/example.org/*.key &>/dev/null
		gpg --import-ownertrust "$FILES"/example.org/trust &>/dev/null
		gpg -k

		git signatures add --push # Author 2
	)
	run git signatures verify --min-count=1
	[ "$status" -eq 1 ]
}

@test "verify with a broken signature" {
	git signatures add

	THIS=$(git rev-parse HEAD)
	git checkout refs/notes/signatures
	openssl base64 -d -A < $THIS > decoded
	head -c -16 decoded > broken
	head -c 16 /dev/zero >> broken
	gpg --list-packets < broken
	openssl base64 -A < broken > $THIS
	git add .
	git commit -m "broken signature packet"
	echo $(git rev-parse HEAD) > .git/refs/notes/signatures

	git checkout master
	run git signatures verify --min-count=1
	[ "$status" -eq 1 ]
	run git signatures show --raw
	[ $(grep "BADSIG" <<< "$output" | wc -l) = 1 ]
}

@test "signatures can't be reused (replay attack)" {
	git signatures add --key "Approver 1"
	git signatures add --key "Approver 2"

	THAT=$(git rev-parse HEAD~1)
	THIS=$(git rev-parse HEAD)
	git checkout refs/notes/signatures
	cp $THIS $THAT
	git add .
	git commit -m "replay attack"
	echo $(git rev-parse HEAD) > .git/refs/notes/signatures

	git checkout master~1
	git signatures show >&2
	run git signatures verify --min-count=2
	[ "$status" -eq 1 ]
}

@test "signatures can't be spoofed by using silly user names" {
	git signatures add --key "Silly 1"
	git signatures add --key "Silly 2"
	git signatures add --key "Sillier"
	run git signatures verify --min-count=1
	[ "$status" -eq 1 ]
}
