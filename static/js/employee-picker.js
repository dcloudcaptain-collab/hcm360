/*
 * Global employee picker — supports individual search, by-department, and
 * custom-group selection. Renders a standalone widget that can live inside
 * any form. Exposes a simple JS API:
 *
 *   const picker = new EmployeePicker(rootEl, {
 *     mode: 'multi' | 'single',     // default 'multi'
 *     inputName: 'target_employee_ids[]',  // hidden input name for selected IDs
 *     allowGroups: true,
 *     allowDepartments: true,
 *     onChange: (ids) => {...},
 *     initial: [{id, name}],
 *   });
 *
 *   picker.getSelected()  -> [{id, name, department}]
 *   picker.clear()
 *
 * Requires the backend endpoints:
 *   GET /api/employees/search?q=
 *   GET /api/departments[?q=]
 *   GET /api/departments/<id>/employees
 *   GET /api/employee-groups[?q=]
 *   GET /api/employee-groups/<id>/members
 */
(function(global){
'use strict';

function escapeHtml(s){
  return String(s == null ? '' : s).replace(/[&<>"']/g, c =>
    ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

function debounce(fn, wait){
  let t = null;
  return function(...args){
    clearTimeout(t);
    t = setTimeout(() => fn.apply(this, args), wait);
  };
}

class EmployeePicker {
  constructor(root, opts){
    opts = opts || {};
    this.root = root;
    this.mode = opts.mode || 'multi';
    this.inputName = opts.inputName || 'employee_ids[]';
    this.allowGroups = opts.allowGroups !== false;
    this.allowDepartments = opts.allowDepartments !== false;
    this.onChange = opts.onChange || null;
    this.placeholder = opts.placeholder || 'Search employees…';
    this.selected = new Map();   // id → { id, name, department, employee_no, source }

    this._render();

    if (opts.initial && Array.isArray(opts.initial)){
      opts.initial.forEach(e => this._addEmployee(e, 'initial'));
    }
  }

  _render(){
    this.root.classList.add('emp-picker');
    this.root.innerHTML = `
      <div class="ep-tabs">
        <button type="button" data-tab="individual" class="ep-tab active">🔍 Individual</button>
        ${this.allowDepartments ? '<button type="button" data-tab="department" class="ep-tab">🏢 Department</button>' : ''}
        ${this.allowGroups ? '<button type="button" data-tab="group" class="ep-tab">👥 Group</button>' : ''}
      </div>
      <div class="ep-search-bar">
        <input type="search" class="ep-search" placeholder="${escapeHtml(this.placeholder)}">
        <div class="ep-hint">Type to search</div>
      </div>
      <div class="ep-results"></div>
      <div class="ep-selected-label">Selected <span class="ep-count">0</span></div>
      <div class="ep-selected"></div>
      <div class="ep-hidden-inputs"></div>
    `;

    this.tabsEl     = this.root.querySelector('.ep-tabs');
    this.searchEl   = this.root.querySelector('.ep-search');
    this.hintEl     = this.root.querySelector('.ep-hint');
    this.resultsEl  = this.root.querySelector('.ep-results');
    this.selectedEl = this.root.querySelector('.ep-selected');
    this.countEl    = this.root.querySelector('.ep-count');
    this.hiddenEl   = this.root.querySelector('.ep-hidden-inputs');

    this.activeTab = 'individual';

    // Tab switch
    this.tabsEl.addEventListener('click', e => {
      const btn = e.target.closest('.ep-tab');
      if (!btn) return;
      this.tabsEl.querySelectorAll('.ep-tab').forEach(x => x.classList.remove('active'));
      btn.classList.add('active');
      this.activeTab = btn.dataset.tab;
      this.searchEl.value = '';
      this.resultsEl.innerHTML = '';
      this._updateHint();
      if (this.activeTab === 'department') this._loadDepartments('');
      else if (this.activeTab === 'group') this._loadGroups('');
    });

    this.searchEl.addEventListener('input', debounce(() => {
      const q = this.searchEl.value.trim();
      if (this.activeTab === 'individual') this._searchEmployees(q);
      else if (this.activeTab === 'department') this._loadDepartments(q);
      else if (this.activeTab === 'group') this._loadGroups(q);
    }, 220));

    this._updateHint();
  }

  _updateHint(){
    const hints = {
      individual: 'Search by name, employee number or email',
      department: 'Pick a department to add everyone in it',
      group: 'Pick a custom group to add all its members',
    };
    this.hintEl.textContent = hints[this.activeTab];
  }

  // ────────────── tab 1: individual ──────────────
  async _searchEmployees(q){
    if (!q) { this.resultsEl.innerHTML = '<div class="ep-empty">Type a name…</div>'; return; }
    try {
      const r = await fetch('/api/employees/search?q=' + encodeURIComponent(q));
      const d = await r.json();
      if (!d.ok || !d.employees.length){
        this.resultsEl.innerHTML = '<div class="ep-empty">No matches</div>';
        return;
      }
      this.resultsEl.innerHTML = d.employees.map(e => `
        <div class="ep-item" data-id="${e.id}">
          <div>
            <div class="ep-item-name">${escapeHtml(e.name)}</div>
            <div class="ep-item-sub">${escapeHtml(e.employee_no || '')} · ${escapeHtml(e.department || '—')}</div>
          </div>
          <button type="button" class="ep-add-btn">+ Add</button>
        </div>`).join('');
      this.resultsEl.querySelectorAll('.ep-add-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          const row = btn.closest('.ep-item');
          const id = parseInt(row.dataset.id, 10);
          const emp = d.employees.find(x => x.id === id);
          if (emp) this._addEmployee(emp, 'individual');
          row.querySelector('.ep-add-btn').textContent = '✓ Added';
          row.querySelector('.ep-add-btn').disabled = true;
        });
      });
    } catch (e) {
      this.resultsEl.innerHTML = '<div class="ep-empty">Search failed</div>';
    }
  }

  // ────────────── tab 2: department ──────────────
  async _loadDepartments(q){
    try {
      const url = '/api/departments' + (q ? '?q=' + encodeURIComponent(q) : '');
      const r = await fetch(url);
      const d = await r.json();
      if (!d.ok || !d.departments.length){
        this.resultsEl.innerHTML = '<div class="ep-empty">No departments</div>';
        return;
      }
      this.resultsEl.innerHTML = d.departments.map(dep => `
        <div class="ep-item" data-id="${dep.id}">
          <div>
            <div class="ep-item-name">${escapeHtml(dep.name)}</div>
            <div class="ep-item-sub">${escapeHtml(dep.code || '')} · ${dep.headcount} employee(s)</div>
          </div>
          <button type="button" class="ep-add-btn">+ Add all</button>
        </div>`).join('');
      this.resultsEl.querySelectorAll('.ep-add-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
          const row = btn.closest('.ep-item');
          const dept_id = parseInt(row.dataset.id, 10);
          btn.textContent = 'Loading…';
          btn.disabled = true;
          try {
            const rr = await fetch(`/api/departments/${dept_id}/employees`);
            const dd = await rr.json();
            const added = (dd.employees || []).filter(e => !this.selected.has(e.id));
            added.forEach(e => this._addEmployee(e, 'department'));
            btn.textContent = `✓ Added ${added.length}`;
          } catch (e) {
            btn.textContent = 'Failed';
            btn.disabled = false;
          }
        });
      });
    } catch (e) {
      this.resultsEl.innerHTML = '<div class="ep-empty">Could not load departments</div>';
    }
  }

  // ────────────── tab 3: group ──────────────
  async _loadGroups(q){
    try {
      const url = '/api/employee-groups' + (q ? '?q=' + encodeURIComponent(q) : '');
      const r = await fetch(url);
      const d = await r.json();
      if (!d.ok || !d.groups.length){
        this.resultsEl.innerHTML =
          '<div class="ep-empty">No groups available. ' +
          '<a href="/admin/employee-groups/new" target="_blank">Create one →</a></div>';
        return;
      }
      this.resultsEl.innerHTML = d.groups.map(g => `
        <div class="ep-item" data-id="${g.id}">
          <div>
            <div class="ep-item-name">${escapeHtml(g.name)}
              <span class="ep-vis ep-vis-${g.visibility}">${g.visibility}</span>
            </div>
            <div class="ep-item-sub">${escapeHtml(g.code || '')} · ${g.member_count} member(s)${g.description ? ' · ' + escapeHtml(g.description.slice(0,70)) : ''}</div>
          </div>
          <button type="button" class="ep-add-btn">+ Add all</button>
        </div>`).join('');
      this.resultsEl.querySelectorAll('.ep-add-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
          const row = btn.closest('.ep-item');
          const gid = parseInt(row.dataset.id, 10);
          btn.textContent = 'Loading…';
          btn.disabled = true;
          try {
            const rr = await fetch(`/api/employee-groups/${gid}/members`);
            const dd = await rr.json();
            const added = (dd.employees || []).filter(e => !this.selected.has(e.id));
            added.forEach(e => this._addEmployee(e, 'group'));
            btn.textContent = `✓ Added ${added.length}`;
          } catch (e) {
            btn.textContent = 'Failed';
            btn.disabled = false;
          }
        });
      });
    } catch (e) {
      this.resultsEl.innerHTML = '<div class="ep-empty">Could not load groups</div>';
    }
  }

  // ────────────── selection management ──────────────
  _addEmployee(emp, source){
    if (!emp || !emp.id) return;
    if (this.mode === 'single') this.selected.clear();
    this.selected.set(emp.id, {
      id: emp.id,
      name: emp.name,
      department: emp.department,
      employee_no: emp.employee_no,
      source: source,
    });
    this._renderSelected();
    if (this.onChange) this.onChange(this.getSelectedIds());
  }

  _remove(id){
    this.selected.delete(id);
    this._renderSelected();
    if (this.onChange) this.onChange(this.getSelectedIds());
  }

  _renderSelected(){
    const arr = Array.from(this.selected.values());
    this.countEl.textContent = arr.length;
    this.selectedEl.innerHTML = arr.length
      ? arr.map(e => `
          <span class="ep-chip" data-id="${e.id}">
            <span>${escapeHtml(e.name)}</span>
            ${e.department ? `<span class="ep-chip-sub">· ${escapeHtml(e.department)}</span>` : ''}
            <button type="button" class="ep-chip-x" aria-label="Remove">✕</button>
          </span>
        `).join('')
      : '<div class="ep-empty">No one selected yet</div>';
    // Hidden inputs for form submission
    this.hiddenEl.innerHTML = arr.map(e =>
      `<input type="hidden" name="${escapeHtml(this.inputName)}" value="${e.id}">`
    ).join('');
    this.selectedEl.querySelectorAll('.ep-chip-x').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = parseInt(btn.closest('.ep-chip').dataset.id, 10);
        this._remove(id);
      });
    });
  }

  // ────────────── public API ──────────────
  getSelected(){ return Array.from(this.selected.values()); }
  getSelectedIds(){ return Array.from(this.selected.keys()); }
  clear(){ this.selected.clear(); this._renderSelected(); }
}

global.EmployeePicker = EmployeePicker;

})(window);
