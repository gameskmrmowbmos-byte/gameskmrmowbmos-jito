import { Navigate, Route, Routes } from 'react-router-dom';
import Shell from './layouts/Shell.jsx';
import Login from './pages/Login.jsx';
import Dashboard from './pages/Dashboard.jsx';
import Users from './pages/Users.jsx';
import Recharges from './pages/Recharges.jsx';
import Plans from './pages/Plans.jsx';
import Markets from './pages/Markets.jsx';
import NumberConfig from './pages/NumberConfig.jsx';
import AuditLogs from './pages/AuditLogs.jsx';
import Settings from './pages/Settings.jsx';
import { useAuth } from './context/AuthContext.jsx';

function RequireAdmin({ children }) {
  const auth = useAuth();
  if (!auth.ready) return null;
  return auth.isAuthenticated ? children : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        path="/"
        element={
          <RequireAdmin>
            <Shell />
          </RequireAdmin>
        }
      >
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<Dashboard />} />
        <Route path="users" element={<Users />} />
        <Route path="recharges" element={<Recharges />} />
        <Route path="plans" element={<Plans />} />
        <Route path="markets" element={<Markets />} />
        <Route path="number-config" element={<NumberConfig />} />
        <Route path="audit-logs" element={<AuditLogs />} />
        <Route path="settings" element={<Settings />} />
      </Route>
    </Routes>
  );
}
