package practice

import (
	"errors"
	"fmt"
	"sync"
)

type ID int

type User struct {
	ID    ID
	Name  string
	Email *string
}

func (u User) Greet() string {
	host := "local"
	if u.Email != nil {
		host = *u.Email
	}
	return fmt.Sprintf("hello %s @ %s", u.Name, host)
}

type Store interface {
	Get(id ID) (User, error)
}

func First[T any](items []T) (T, error) {
	var zero T
	if len(items) == 0 {
		return zero, errors.New("empty")
	}
	return items[0], nil
}

func FanIn(left, right <-chan string) <-chan string {
	out := make(chan string)
	go func() {
		defer close(out)
		for left != nil || right != nil {
			select {
			case value, ok := <-left:
				if !ok {
					left = nil
					continue
				}
				out <- value
			case value, ok := <-right:
				if !ok {
					right = nil
					continue
				}
				out <- value
			}
		}
	}()
	return out
}

func Count(n int) int {
	var mu sync.Mutex
	total := 0
	var wg sync.WaitGroup
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func() {
			defer wg.Done()
			mu.Lock()
			total++
			mu.Unlock()
		}()
	}
	wg.Wait()
	return total
}
