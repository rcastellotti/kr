package main

import (
	"fmt"
	"os"
	"syscall"

	"github.com/zalando/go-keyring"
	"golang.org/x/term"
)

func usage() {
	fmt.Printf(`kr - micro KeyRing manager

Usage:
  kr <command> [arguments]

Commands:
  set <service> <user>    Save (or update) a password for the given service and user
  get <service> <user>    Retrieve a password for the given service and user
  del <service> <user>    Delete a password for the given service and user
  help                    Show this help message
`)
}

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}

	cmd := os.Args[1]

	switch cmd {
	case "help", "--help", "-h":
		usage()

	case "set":
		if len(os.Args) != 4 {
			fmt.Fprintln(os.Stderr, "Usage: kr set <service> <user>")
			os.Exit(1)
		}
		service, user := os.Args[2], os.Args[3]

		fmt.Printf("Enter password for %s@%s: ", user, service)
		raw, err := term.ReadPassword(int(syscall.Stdin))
		fmt.Println()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading password: %v\n", err)
			os.Exit(1)
		}

		if err := keyring.Set(service, user, string(raw)); err != nil {
			fmt.Fprintf(os.Stderr, "Error saving password: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Password saved for %s@%s\n", user, service)

	case "get":
		if len(os.Args) != 4 {
			fmt.Fprintln(os.Stderr, "Usage: kr get <service> <user>")
			os.Exit(1)
		}
		service, user := os.Args[2], os.Args[3]

		password, err := keyring.Get(service, user)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error retrieving password: %v\n", err)
			os.Exit(1)
		}
		fmt.Println(password)

	case "del":
		if len(os.Args) != 4 {
			fmt.Fprintln(os.Stderr, "Usage: kr del <service> <user>")
			os.Exit(1)
		}
		service, user := os.Args[2], os.Args[3]

		if err := keyring.Delete(service, user); err != nil {
			fmt.Fprintf(os.Stderr, "Error deleting password: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Password deleted for %s@%s\n", user, service)

	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %q\n\n", cmd)
		usage()
		os.Exit(1)
	}
}
