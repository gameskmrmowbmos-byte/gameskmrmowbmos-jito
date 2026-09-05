import { useQuery } from '@tanstack/react-query';
import { api } from '../api/client.js';

export default function AuditLogs() {
  const { data } = useQuery({ queryKey: ['audit-logs'], queryFn: async () => (await api.get('/admin/audit-logs')).data.data.logs });
  return (
    <section>
      <div className="page-title"><h1>Audit Logs</h1><p>Sensitive admin and system activity.</p></div>
      <div className="table-wrap"><table><thead><tr><th>Time</th><th>Admin/User</th><th>Action</th><th>Module</th></tr></thead><tbody>{(data || []).map((log) => <tr key={log._id}><td>{new Date(log.timestamp).toLocaleString()}</td><td>{log.user?.username || '-'}</td><td>{log.action}</td><td>{log.module}</td></tr>)}</tbody></table></div>
    </section>
  );
}
