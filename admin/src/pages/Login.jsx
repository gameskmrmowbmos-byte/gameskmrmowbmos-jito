import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiMessage } from '../api/client.js';
import { useAuth } from '../context/AuthContext.jsx';

export default function Login() {
  const auth = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ identifier: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (event) => {
    event.preventDefault();
    setLoading(true);
    setError('');
    try {
      await auth.login(form);
      navigate('/dashboard', { replace: true });
    } catch (err) {
      setError(apiMessage(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="login-page">
      <form className="login-card" onSubmit={submit}>
        <h1>Admin Login</h1>
        <label>
          Email / Username
          <input
            value={form.identifier}
            onChange={(e) => setForm({ ...form, identifier: e.target.value })}
          />
        </label>
        <label>
          Password
          <input
            value={form.password}
            onChange={(e) => setForm({ ...form, password: e.target.value })}
            type="password"
          />
        </label>
        {error && <div className="alert error">{error}</div>}
        <button type="submit" disabled={loading}>{loading ? 'Signing in...' : 'Login'}</button>
      </form>
    </main>
  );
}
