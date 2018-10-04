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

@test "verify with a revoked key" {
	git signatures add --key "Approver 1"
	git signatures add --key "Approver 2"
	git signatures verify --min-count=2

	gpg --import "$FILES"/keys/approver1.rev
	git signatures verify --min-count=1
	run git signatures verify --min-count=2
	[ "$status" -eq 1 ]
}
