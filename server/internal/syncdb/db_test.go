package syncdb

import (
	"context"
	"fmt"
	"path/filepath"
	"sync"
	"testing"
)

func uid(n int) string { return fmt.Sprintf("00000000-0000-4000-8000-%012d", n) }
func request() Request {
	return Request{Device: "test-device", Children: map[string][]Event{"qianyi": {}, "zhenyi": {}}}
}
func award(id int, reference string) Event {
	return Event{uid(id), 1700000000000, "award", reference, "测试", Catalog[reference]}
}
func openTest(t *testing.T) *DB {
	t.Helper()
	db, err := Open(filepath.Join(t.TempDir(), "family.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}
func TestOfflineAwardsAndSemanticDedup(t *testing.T) {
	d := openTest(t)
	r := request()
	r.Children["qianyi"] = []Event{award(1, "numberLine:1:1")}
	a, err := d.Sync(context.Background(), r)
	if err != nil || a.Balances["qianyi"] != 1 {
		t.Fatal(a, err)
	}
	r.Device = "second"
	r.Children["qianyi"][0].ID = uid(2)
	a, err = d.Sync(context.Background(), r)
	if err != nil || a.Balances["qianyi"] != 1 || len(a.Children["qianyi"]) != 1 {
		t.Fatal(a, err)
	}
	if a.Balances["zhenyi"] != 0 {
		t.Fatal("child data leaked")
	}
}
func TestConcurrentSpendingAndIdempotence(t *testing.T) {
	d := openTest(t)
	r := request()
	r.Children["qianyi"] = []Event{award(1, "numberLine:1:1")}
	if _, err := d.Sync(context.Background(), r); err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	success := 0
	var mu sync.Mutex
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func(n int) {
			defer wg.Done()
			x := request()
			x.Device = fmt.Sprint("device", n)
			x.Operation = &Operation{ID: uid(10 + n), Child: "qianyi", Kind: "redemption", Title: "书", Points: 1}
			if _, err := d.Sync(context.Background(), x); err == nil {
				mu.Lock()
				success++
				mu.Unlock()
				if _, err = d.Sync(context.Background(), x); err != nil {
					t.Error("retry", err)
				}
			}
		}(i)
	}
	wg.Wait()
	if success != 1 {
		t.Fatalf("double spend: %d", success)
	}
	a, _ := d.Snapshot(context.Background())
	if a.Balances["qianyi"] != 0 {
		t.Fatal(a)
	}
}
func TestRefundOnceAndIllegalClientSpending(t *testing.T) {
	d := openTest(t)
	r := request()
	r.Children["qianyi"] = []Event{award(1, "numberLine:1:1")}
	r.Operation = &Operation{ID: uid(2), Child: "qianyi", Kind: "redemption", Title: "书", Points: 1}
	if _, err := d.Sync(context.Background(), r); err != nil {
		t.Fatal(err)
	}
	r.Children["qianyi"] = nil
	r.Operation = &Operation{ID: uid(3), Child: "qianyi", Kind: "refund", Reference: uid(2)}
	if _, err := d.Sync(context.Background(), r); err != nil {
		t.Fatal(err)
	}
	r.Operation.ID = uid(4)
	if _, err := d.Sync(context.Background(), r); err != nil {
		t.Fatal(err)
	}
	a, _ := d.Snapshot(context.Background())
	if a.Balances["qianyi"] != 1 || len(a.Children["qianyi"]) != 3 {
		t.Fatal(a)
	}
	r.Operation = nil
	r.Children["qianyi"] = []Event{{ID: uid(9), Date: 1700000000000, Kind: "redemption", Title: "offline forged", Reference: "manual", Amount: -1}}
	if _, err := d.Sync(context.Background(), r); err == nil {
		t.Fatal("unconfirmed spending accepted")
	}
}
func TestHistoricalImportAndRollback(t *testing.T) {
	d := openTest(t)
	r := request()
	r.Children["qianyi"] = []Event{award(1, "numberLine:1:1"), {ID: uid(2), Date: 1700000000000, Kind: "redemption", Reference: "manual", Title: "书", Amount: -2}}
	if _, err := d.Import(context.Background(), r); err == nil {
		t.Fatal("overspend imported")
	}
	a, _ := d.Snapshot(context.Background())
	if len(a.Children["qianyi"]) != 0 {
		t.Fatal("partial import")
	}
	r.Children["qianyi"][1].Amount = -1
	if _, err := d.Import(context.Background(), r); err != nil {
		t.Fatal(err)
	}
	if _, err := d.Import(context.Background(), r); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "backup.db")
	if err := d.Backup(context.Background(), path); err != nil {
		t.Fatal(err)
	}
	b, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer b.Close()
	a, _ = b.Snapshot(context.Background())
	if a.Balances["qianyi"] != 0 || len(a.Children["qianyi"]) != 2 {
		t.Fatal(a)
	}
}
func TestBadAwardAndConflictingID(t *testing.T) {
	d := openTest(t)
	r := request()
	bad := award(1, "numberLine:1:1")
	bad.Amount = 100
	r.Children["qianyi"] = []Event{bad}
	if _, err := d.Sync(context.Background(), r); err == nil {
		t.Fatal("bad award")
	}
	r.Children["qianyi"] = []Event{award(1, "numberLine:1:1")}
	d.Sync(context.Background(), r)
	r.Children["qianyi"] = []Event{award(1, "numberLine:2:1")}
	if _, err := d.Sync(context.Background(), r); err == nil {
		t.Fatal("conflicting ID")
	}
	r = request()
	r.Children["other"] = nil
	if _, err := d.Sync(context.Background(), r); err == nil {
		t.Fatal("unknown child")
	}
}
