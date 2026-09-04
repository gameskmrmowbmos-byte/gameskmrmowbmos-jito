import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { api } from '../api/client.js';

export default function NumberConfig() {
  const [search, setSearch] = useState('');
  const { data } = useQuery({ queryKey: ['number-config', search], queryFn: async () => (await api.get('/admin/number-config', { params: { search } })).data.data });
  return (
    <section>
      <div className="page-title"><h1>Number / Panna Configuration</h1><p>Read-only STANDARD_220_PANNA verification.</p></div>
      <div className="stats-grid"><div className="stat-card"><span>Code</span><strong>{data?.code}</strong></div><div className="stat-card"><span>Total Panna Count</span><strong>{data?.totalPannaCount || 0}</strong></div><div className="stat-card"><span>Mode</span><strong>{data?.readOnly ? 'Read Only' : 'Editable'}</strong></div></div>
      <div className="toolbar"><input placeholder="Search number" value={search} onChange={(e) => setSearch(e.target.value)} /></div>
      <div className="cards compact">{(data?.values || []).slice(0, 220).map((item, index) => <div className="mini-card" key={`${item.value || item}-${index}`}>{item.value || item}<span>{item.pannaType || ''}</span></div>)}</div>
    </section>
  );
}
