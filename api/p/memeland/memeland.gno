package memeland

import (
	"std"
	"strconv"
	"strings"
	"time"
	"sort"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/seqid"
)

type Post struct {
	ID            string
	Data          string
	Author        std.Address
	Timestamp     time.Time
	UpvoteTracker *avl.Tree // address > struct{}{}
}

type Memeland struct {
	Posts       []*Post
	MemeCounter seqid.ID
}

// NewMemeland returns a pointer to a new Memeland object
// Initializes all the subfields

var id seqid.ID

func NewMemeland() *Memeland {

	m := &Memeland{
		Posts: []*Post{},
		MemeCounter: 0,
	}
	return m
	// memeCounter := seqid.ID(id.Next().Binary())
	// return &Memeland{
	// 						Posts:       []*Post{},
	// 						MemeCounter: memeCounter,
	// 		}
}

// PostMeme - Adds a new post at timestamp, with data
// Panics in case data is empty or timestamp is invalid
// Returns the ID of the created Post
func (m *Memeland) PostMeme(data string, timestamp int64) string {
	if data == "" {
		panic("data is empty")
	}

	if timestamp < 0 {
		panic("timestamp is invalid")
	}

	postTime := time.Unix(timestamp, 0)
	
	post := Post{
		Data:      data,
		Timestamp: postTime,
		ID:        m.MemeCounter.Next().String(),
		UpvoteTracker: avl.NewTree(), 
	}

	m.Posts = append(m.Posts, &post)

	return m.Posts[len(m.Posts)-1].ID
}



// Upvote increases the upvote count of a specific Post
// Panics if specified ID doesn't exist, or the user has already upvoted
func (m *Memeland) Upvote(id string) string {
	post :=	m.getPost(id)

	if post == nil {
		panic("the user has already upvoted")
	}

	caller := std.PrevRealm().Addr().String();

	var isUpvoted = post.UpvoteTracker.Has(caller)

	if isUpvoted == true {
		panic("the user has already upvoted")
	}

	post.UpvoteTracker.Set(caller, 1)

	return "upvote successful"
}

// GetPostsInRange returns a JSON object containing marshalled Posts in a specific timestamp range
// Timestamps are given as Unix seconds
// Supports pagination
// sortBy can be "UPVOTES" (most upvotes-first), or "DATE_CREATED" (newest-first)
// Panics if page < 1, pageSize < 1, or pageSize > 10
// Returns empty JSON object if there are no posts in the specified range.

// Define a slice of Person
type ByUpvotes struct {
	posts []*Post
}
func (a ByUpvotes) Len() int           { return len(a.posts) }
func (a ByUpvotes) Swap(i, j int)      { a.posts[i], a.posts[j] = a.posts[j], a.posts[i] }
func (a ByUpvotes) Less(i, j int) bool { return a.posts[i].UpvoteTracker.Size() < a.posts[j].UpvoteTracker.Size() }


type ByTimestamp struct {
	posts []*Post
}
func (a ByTimestamp) Len() int           { return len(a.posts) }
func (a ByTimestamp) Swap(i, j int)      { a.posts[i], a.posts[j] = a.posts[j], a.posts[i] }
func (a ByTimestamp) Less(i, j int) bool { return a.posts[i].Timestamp.After(a.posts[j].Timestamp) }

func (m *Memeland) GetPostsInRange(startTimestamp, endTimestamp int64, page, pageSize int, sortBy string) string {
	if page < 1 || pageSize < 1 || pageSize > 10 {
					panic("Invalid page or pageSize")
	}

	var filteredPosts []*Post
	
	for _, post := range m.Posts {
		if !post.Timestamp.Before(time.Unix(startTimestamp, 0)) && !post.Timestamp.After(time.Unix(endTimestamp, 0)) {
			filteredPosts = append(filteredPosts, post)
		}
	}

	switch sortBy {
		case "UPVOTES":
			sort.Sort(ByUpvotes{
				posts: filteredPosts,
			})
		default:
			sort.Sort(ByTimestamp{
				posts: filteredPosts,
			})
	}

		startIndex := (page - 1) * pageSize
		endIndex := startIndex + pageSize

		if startIndex >= len(filteredPosts) {
			return "[]"
		}

		if endIndex > len(filteredPosts) {
			endIndex = len(filteredPosts)
		}

		paginatedPosts := filteredPosts[startIndex:endIndex]
		return PostsToJSONString(filteredPosts)
}

// getPost gets a post by ID
func (m *Memeland) getPost(id string) *Post {
	for _, post := range m.Posts {
					if post.ID == id {
									return post
					}
	}

	return nil
}

// PostsToJSONString converts a slice of Post structs into a JSON string
func PostsToJSONString(posts []*Post) string {
	var sb strings.Builder
	sb.WriteString("[")

	for i, post := range posts {
		if i > 0 {
			sb.WriteString(",")
		}

		sb.WriteString(PostToJSONString(post))
	}
	sb.WriteString("]")

	return sb.String()
}

// PostToJSONString returns a Post formatted as a JSON string
// Note: Gno currently does not support reflection, which is why JSON marshalling is unavailable
func PostToJSONString(post *Post) string {
	var sb strings.Builder

	sb.WriteString("{")
	sb.WriteString(`"id":"` + post.ID + `",`)
	sb.WriteString(`"data":"` + escapeString(post.Data) + `",`)
	sb.WriteString(`"author":"` + escapeString(post.Author.String()) + `",`)
	sb.WriteString(`"timestamp":"` + strconv.Itoa(int(post.Timestamp.Unix())) + `",`)
	sb.WriteString(`"upvotes":` + strconv.Itoa(post.UpvoteTracker.Size()))
	sb.WriteString("}")

	return sb.String()
}

// escapeString escapes quotes in a string for JSON compatibility.
func escapeString(s string) string {
	return strings.ReplaceAll(s, `"`, `\"`)
}
