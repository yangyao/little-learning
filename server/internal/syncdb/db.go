package syncdb

import (
	"context"
	"crypto/subtle"
	"database/sql"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	_ "modernc.org/sqlite"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

//go:embed catalog.json
var catalogJSON []byte
var Catalog map[string]int

func init() {
	if err := json.Unmarshal(catalogJSON, &Catalog); err != nil {
		panic(err)
	}
}

type Event struct {
	ID        string  `json:"id"`
	Date      float64 `json:"date"`
	Kind      string  `json:"kind"`
	Reference string  `json:"reference"`
	Title     string  `json:"title"`
	Amount    int     `json:"amount"`
}
type Operation struct {
	ID        string `json:"id"`
	Child     string `json:"child"`
	Kind      string `json:"kind"`
	Title     string `json:"title"`
	Points    int    `json:"points"`
	Reference string `json:"reference"`
}
type Request struct {
	Device    string             `json:"device"`
	Children  map[string][]Event `json:"children"`
	Operation *Operation         `json:"operation,omitempty"`
}
type Response struct {
	Children map[string][]Event `json:"children"`
	Balances map[string]int     `json:"balances"`
	Error    string             `json:"error,omitempty"`
	Applied  string             `json:"applied,omitempty"`
}
type DB struct {
	sql  *sql.DB
	mu   sync.Mutex
	path string
}

var ErrConflict = errors.New("记录冲突，已保留本机数据")
var ErrFunds = errors.New("同步后的积分不足，本次没有扣分")

func validChild(s string) bool { return s == "qianyi" || s == "zhenyi" }
func uuid(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i, r := range s {
		if i == 8 || i == 13 || i == 18 || i == 23 {
			if r != '-' {
				return false
			}
		} else if !strings.ContainsRune("0123456789abcdefABCDEF", r) {
			return false
		}
	}
	return true
}
func norm(e Event) Event {
	e.ID = strings.ToUpper(e.ID)
	if e.Kind == "refund" {
		e.Reference = strings.ToUpper(e.Reference)
	}
	e.Date = math.Round(e.Date)
	return e
}
func validEvent(e Event) bool {
	if !uuid(e.ID) || e.Title == "" || len(e.Title) > 1000 || math.IsNaN(e.Date) || math.IsInf(e.Date, 0) || e.Date < 0 || e.Date > 4102444800000 {
		return false
	}
	switch e.Kind {
	case "award":
		return Catalog[e.Reference] > 0 && e.Amount == Catalog[e.Reference]
	case "redemption":
		return e.Amount < 0 && e.Amount >= -1000000
	case "playTime":
		return e.Amount == -5 && e.Reference == "play-time:5-minutes"
	case "refund":
		return e.Amount > 0 && e.Amount <= 1000000 && uuid(e.Reference)
	}
	return false
}
func Open(path string) (*DB, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return nil, err
	}
	s, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	s.SetMaxOpenConns(1)
	_, err = s.Exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000; PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS events(id TEXT PRIMARY KEY,child TEXT NOT NULL,kind TEXT NOT NULL,reference TEXT NOT NULL,title TEXT NOT NULL,amount INTEGER NOT NULL,date REAL NOT NULL,device TEXT NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS award_once ON events(child,reference) WHERE kind='award';
CREATE UNIQUE INDEX IF NOT EXISTS refund_once ON events(child,reference) WHERE kind='refund';
CREATE TABLE IF NOT EXISTS devices(id TEXT PRIMARY KEY,last_seen INTEGER NOT NULL);`)
	if err != nil {
		s.Close()
		return nil, err
	}
	os.Chmod(path, 0600)
	return &DB{sql: s, path: path}, nil
}
func (d *DB) Close() error { return d.sql.Close() }
func same(a, b Event) bool {
	return a.ID == b.ID && a.Kind == b.Kind && a.Reference == b.Reference && a.Amount == b.Amount && (a.Kind == "award" || a.Title == b.Title)
}
func find(ctx context.Context, tx *sql.Tx, id string) (Event, string, string, error) {
	var e Event
	var child, device string
	err := tx.QueryRowContext(ctx, `SELECT id,child,kind,reference,title,amount,date,device FROM events WHERE id=?`, id).Scan(&e.ID, &child, &e.Kind, &e.Reference, &e.Title, &e.Amount, &e.Date, &device)
	return e, child, device, err
}
func insert(ctx context.Context, tx *sql.Tx, child, device string, e Event, allowHistory bool) error {
	e = norm(e)
	if !validChild(child) || !validEvent(e) {
		return fmt.Errorf("无效记录")
	}
	old, owner, _, err := find(ctx, tx, e.ID)
	if err == nil {
		if owner != child || !same(old, e) {
			return ErrConflict
		}
		return nil
	}
	if err != sql.ErrNoRows {
		return err
	}
	if e.Kind == "award" || e.Kind == "refund" {
		var id string
		err = tx.QueryRowContext(ctx, `SELECT id FROM events WHERE child=? AND kind=? AND reference=?`, child, e.Kind, e.Reference).Scan(&id)
		if err == nil {
			existing, _, _, err := find(ctx, tx, id)
			if err != nil {
				return err
			}
			if existing.Amount != e.Amount {
				return ErrConflict
			}
			return nil
		}
		if err != sql.ErrNoRows {
			return err
		}
	}
	if e.Kind != "award" && !allowHistory {
		return fmt.Errorf("有尚未迁入的历史兑换，请保留本机记录并联系家长")
	}
	if e.Kind == "refund" {
		original, owner, _, err := find(ctx, tx, e.Reference)
		if err != nil || owner != child || original.Kind != "redemption" || e.Amount != -original.Amount {
			return fmt.Errorf("无效撤销记录")
		}
	}
	_, err = tx.ExecContext(ctx, `INSERT INTO events(id,child,kind,reference,title,amount,date,device) VALUES(?,?,?,?,?,?,?,?)`, e.ID, child, e.Kind, e.Reference, e.Title, e.Amount, e.Date, device)
	return err
}
func balance(ctx context.Context, tx *sql.Tx, child string) (int, error) {
	var n int
	err := tx.QueryRowContext(ctx, `SELECT COALESCE(SUM(amount),0) FROM events WHERE child=?`, child).Scan(&n)
	return n, err
}
func apply(ctx context.Context, tx *sql.Tx, device string, o *Operation) (string, error) {
	if o == nil {
		return "", nil
	}
	o.ID = strings.ToUpper(o.ID)
	o.Reference = strings.ToUpper(o.Reference)
	if !uuid(o.ID) || !validChild(o.Child) || len(o.Title) > 240 {
		return "", fmt.Errorf("无效操作")
	}
	amount := 0
	ref := "manual"
	title := strings.TrimSpace(o.Title)
	switch o.Kind {
	case "redemption":
		if o.Points < 1 || o.Points > 1000000 || title == "" {
			return "", fmt.Errorf("无效兑换")
		}
		amount = -o.Points
	case "playTime":
		if o.Points != 5 {
			return "", fmt.Errorf("无效游玩兑换")
		}
		amount = -5
		ref = "play-time:5-minutes"
		title = "趣味游戏 · 5分钟"
	case "refund":
		original, child, _, err := find(ctx, tx, o.Reference)
		if err != nil || child != o.Child || original.Kind != "redemption" {
			return "", fmt.Errorf("这笔兑换不能撤销")
		}
		amount = -original.Amount
		ref = original.ID
		title = "撤销 · " + original.Title
	default:
		return "", fmt.Errorf("无效操作")
	}
	e := Event{o.ID, float64(time.Now().UnixMilli()), o.Kind, ref, title, amount}
	old, owner, oldDevice, err := find(ctx, tx, e.ID)
	if err == nil {
		if owner != o.Child || oldDevice != device || !same(old, e) {
			return "", ErrConflict
		}
		return e.ID, nil
	}
	if err != sql.ErrNoRows {
		return "", err
	}
	if o.Kind == "refund" {
		var existing string
		err := tx.QueryRowContext(ctx, `SELECT id FROM events WHERE child=? AND kind='refund' AND reference=?`, o.Child, ref).Scan(&existing)
		if err == nil {
			return existing, nil
		}
		if err != sql.ErrNoRows {
			return "", err
		}
	}
	available, err := balance(ctx, tx, o.Child)
	if err != nil {
		return "", err
	}
	if available+amount < 0 {
		return "", ErrFunds
	}
	return e.ID, insert(ctx, tx, o.Child, device, e, true)
}
func (d *DB) Sync(ctx context.Context, r Request) (Response, error) { return d.write(ctx, r, false) }
func (d *DB) Import(ctx context.Context, r Request) (Response, error) {
	if r.Operation != nil {
		return Response{}, fmt.Errorf("import does not accept operations")
	}
	return d.write(ctx, r, true)
}
func (d *DB) write(ctx context.Context, r Request, history bool) (Response, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	if len(r.Device) < 1 || len(r.Device) > 120 || len(r.Children) != 2 {
		return Response{}, fmt.Errorf("无效设备或家庭")
	}
	if _, ok := r.Children["qianyi"]; !ok {
		return Response{}, fmt.Errorf("缺少档案")
	}
	if _, ok := r.Children["zhenyi"]; !ok {
		return Response{}, fmt.Errorf("缺少档案")
	}
	tx, err := d.sql.BeginTx(ctx, nil)
	if err != nil {
		return Response{}, err
	}
	defer tx.Rollback()
	for _, kind := range []string{"award", "redemption", "playTime", "refund"} {
		for child, events := range r.Children {
			if len(events) > 10000 {
				return Response{}, fmt.Errorf("记录过多")
			}
			for _, event := range events {
				if event.Kind != kind {
					continue
				}
				if err = insert(ctx, tx, child, r.Device, event, history); err != nil {
					return Response{}, err
				}
			}
		}
	}
	for _, events := range r.Children {
		for _, e := range events {
			if !validEvent(norm(e)) {
				return Response{}, fmt.Errorf("无效记录")
			}
		}
	}
	applied, err := apply(ctx, tx, r.Device, r.Operation)
	if err != nil {
		return Response{}, err
	}
	for _, child := range []string{"qianyi", "zhenyi"} {
		n, err := balance(ctx, tx, child)
		if err != nil {
			return Response{}, err
		}
		if n < 0 {
			return Response{}, ErrFunds
		}
	}
	_, err = tx.ExecContext(ctx, `INSERT INTO devices(id,last_seen) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET last_seen=excluded.last_seen`, r.Device, time.Now().Unix())
	if err != nil {
		return Response{}, err
	}
	if err = tx.Commit(); err != nil {
		return Response{}, err
	}
	response, err := d.snapshot(ctx)
	response.Applied = applied
	return response, err
}
func (d *DB) Snapshot(ctx context.Context) (Response, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.snapshot(ctx)
}
func (d *DB) snapshot(ctx context.Context) (Response, error) {
	out := Response{Children: map[string][]Event{"qianyi": {}, "zhenyi": {}}, Balances: map[string]int{"qianyi": 0, "zhenyi": 0}}
	rows, err := d.sql.QueryContext(ctx, `SELECT id,child,kind,reference,title,amount,date FROM events ORDER BY id`)
	if err != nil {
		return out, err
	}
	defer rows.Close()
	for rows.Next() {
		var child string
		var e Event
		if err = rows.Scan(&e.ID, &child, &e.Kind, &e.Reference, &e.Title, &e.Amount, &e.Date); err != nil {
			return out, err
		}
		out.Children[child] = append(out.Children[child], e)
		out.Balances[child] += e.Amount
	}
	if err = rows.Err(); err != nil {
		return out, err
	}
	for child, events := range out.Children {
		var awards, spent, rest []Event
		refunds := map[string]Event{}
		for _, e := range events {
			if e.Kind == "refund" {
				refunds[e.Reference] = e
			} else if e.Kind == "award" {
				awards = append(awards, e)
			} else {
				spent = append(spent, e)
			}
		}
		sort.Slice(awards, func(i, j int) bool { return awards[i].Reference < awards[j].Reference })
		ordered := append([]Event{}, awards...)
		for _, e := range spent {
			if refund, ok := refunds[e.ID]; ok {
				ordered = append(ordered, e, refund)
			} else {
				rest = append(rest, e)
			}
		}
		out.Children[child] = append(ordered, rest...)
	}
	return out, nil
}
func (d *DB) Backup(ctx context.Context, destination string) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	if err := os.MkdirAll(filepath.Dir(destination), 0700); err != nil {
		return err
	}
	_, err := d.sql.ExecContext(ctx, `VACUUM INTO ?`, destination)
	if err == nil {
		os.Chmod(destination, 0600)
	}
	return err
}
func TokenEqual(a, b string) bool {
	return len(a) == len(b) && subtle.ConstantTimeCompare([]byte(a), []byte(b)) == 1
}
