import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { api, apiMessage } from '../api/client.js';

const blank = {
  name: '',
  code: '',
  resultTime: '21:30',
  description: '',
  isActive: true,
};

export default function Markets() {
  const qc = useQueryClient();
  const [form, setForm] = useState(blank);
  const [editingId, setEditingId] = useState(null);
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [orderedMarkets, setOrderedMarkets] = useState([]);
  const [draggingId, setDraggingId] = useState(null);
  const [orderError, setOrderError] = useState('');
  const { data } = useQuery({
    queryKey: ['admin-markets'],
    queryFn: async () => (await api.get('/admin/markets')).data.data.markets,
  });
  useEffect(() => {
    setOrderedMarkets(data || []);
  }, [data]);
  const save = useMutation({
    mutationFn: async () => {
      const payload = { ...form, code: form.code.trim().toUpperCase() };
      return editingId
        ? api.put(`/admin/markets/${editingId}`, payload)
        : api.post('/admin/markets', payload);
    },
    onSuccess: () => {
      setForm(blank);
      setEditingId(null);
      qc.invalidateQueries({ queryKey: ['admin-markets'] });
    },
  });
  const status = useMutation({
    mutationFn: async ({ id, active }) => api.post(`/admin/markets/${id}/${active ? 'deactivate' : 'activate'}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-markets'] }),
  });
  const remove = useMutation({
    mutationFn: async (id) => api.delete(`/admin/markets/${id}`),
    onSuccess: () => {
      setDeleteTarget(null);
      qc.invalidateQueries({ queryKey: ['admin-markets'] });
    },
  });
  const reorder = useMutation({
    mutationFn: async ({ nextMarkets }) =>
      api.put('/admin/markets/reorder', {
        marketIds: nextMarkets.map((market) => market._id),
      }),
    onSuccess: () => {
      setOrderError('');
      qc.invalidateQueries({ queryKey: ['admin-markets'] });
    },
    onError: (error, variables) => {
      if (variables?.previousMarkets) setOrderedMarkets(variables.previousMarkets);
      setOrderError(apiMessage(error) || 'Unable to save market order. Please try again.');
    },
  });

  function editMarket(market) {
    setEditingId(market._id);
    setForm({
      name: market.name || '',
      code: market.code || '',
      resultTime: market.resultTime || '21:30',
      description: market.description || '',
      isActive: market.isActive !== false,
    });
  }

  function moveMarket(sourceId, targetId) {
    if (!sourceId || !targetId || sourceId === targetId) return;
    const previousMarkets = orderedMarkets;
    const sourceIndex = previousMarkets.findIndex((market) => market._id === sourceId);
    const targetIndex = previousMarkets.findIndex((market) => market._id === targetId);
    if (sourceIndex < 0 || targetIndex < 0) return;
    const nextMarkets = [...previousMarkets];
    const [moved] = nextMarkets.splice(sourceIndex, 1);
    nextMarkets.splice(targetIndex, 0, moved);
    setOrderedMarkets(nextMarkets);
    reorder.mutate({ nextMarkets, previousMarkets });
  }

  function handleDragStart(event, marketId) {
    setDraggingId(marketId);
    event.dataTransfer.effectAllowed = 'move';
    event.dataTransfer.setData('text/plain', marketId);
  }

  function handleDrop(event, targetId) {
    event.preventDefault();
    const sourceId = event.dataTransfer.getData('text/plain') || draggingId;
    setDraggingId(null);
    moveMarket(sourceId, targetId);
  }

  return (
    <section>
      <div className="page-title"><h1>Markets</h1><p>Central market control for Flutter app.</p></div>
      <div className="panel form-grid">
        <input required aria-label="Market Name" placeholder="Market Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
        <input required aria-label="Market Code" placeholder="Code" value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value })} />
        <label>Result Time<input required type="time" value={form.resultTime} onChange={(e) => setForm({ ...form, resultTime: e.target.value })} /></label>
        <label className="check"><input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} /> Active</label>
        <input aria-label="Description" placeholder="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
        <button className="primary" onClick={() => save.mutate()} disabled={save.isPending}>
          {editingId ? 'Save Market' : 'Add Market'}
        </button>
        {editingId && <button onClick={() => { setForm(blank); setEditingId(null); }}>Cancel Edit</button>}
      </div>
      {save.error && <div className="alert error">{apiMessage(save.error)}</div>}
      {status.error && <div className="alert error">{apiMessage(status.error)}</div>}
      {remove.error && <div className="alert error">{apiMessage(remove.error)}</div>}
      {orderError && <div className="alert error">{orderError}</div>}
      {reorder.isPending && <div className="alert success">Saving market order...</div>}
      <div className="table-wrap">
        <table>
          <thead><tr><th>Order</th><th>Name</th><th>Code</th><th>Result</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>{orderedMarkets.map((m, index) => (
            <tr
              key={m._id}
              className={draggingId === m._id ? 'dragging-row' : ''}
              onDragOver={(event) => event.preventDefault()}
              onDrop={(event) => handleDrop(event, m._id)}
            >
              <td className="order-cell">
                <span
                  className="drag-handle"
                  title="Drag to reorder"
                  draggable
                  onDragStart={(event) => handleDragStart(event, m._id)}
                  onDragEnd={() => setDraggingId(null)}
                >
                  =
                </span>
                <strong>{index + 1}</strong>
              </td>
              <td>{m.name}</td>
              <td>{m.code}</td>
              <td>{m.resultTime || '-'}</td>
              <td><span className="badge">{m.isActive ? 'ACTIVE' : 'INACTIVE'}</span></td>
              <td className="actions">
                <button onClick={() => editMarket(m)}>Edit</button>
                <button onClick={() => status.mutate({ id: m._id, active: m.isActive })}>{m.isActive ? 'Deactivate' : 'Activate'}</button>
                <button className="danger" onClick={() => setDeleteTarget(m)}>Delete</button>
              </td>
            </tr>
          ))}</tbody>
        </table>
      </div>
      {deleteTarget && (
        <div className="modal-backdrop">
          <div className="modal">
            <h2>Delete Market?</h2>
            <p>Are you sure you want to delete &quot;{deleteTarget.name}&quot;?</p>
            <p className="muted">This action cannot be undone for markets without history. Markets with receipt history are safely hidden instead.</p>
            <div className="modal-actions">
              <button onClick={() => setDeleteTarget(null)}>Cancel</button>
              <button className="danger" onClick={() => remove.mutate(deleteTarget._id)}>Delete</button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
