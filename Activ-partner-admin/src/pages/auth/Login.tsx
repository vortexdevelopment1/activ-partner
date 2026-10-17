import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { Eye, EyeOff } from 'lucide-react';
import { authApi } from '../../api/auth.api';
import { useAuthStore } from '../../store/auth.store';

interface LoginForm {
  email: string;
  password: string;
}

export const Login: React.FC = () => {
  const navigate = useNavigate();
  const { setAuth } = useAuthStore();
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginForm>();

  const onSubmit = async (data: LoginForm) => {
    setError('');
    try {
      const res = await authApi.login(data.email, data.password);
      setAuth(res.data.data.user, res.data.data.accessToken);
      navigate('/dashboard');
    } catch (err: any) {
      setError(err?.response?.data?.message || 'Invalid email or password');
    }
  };

  return (
    <div className="auth-background min-h-dvh flex items-center justify-center p-4 sm:p-6">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <img src="/activ-partner-logo.png" alt="ACTIV Partner" className="w-44 h-auto mx-auto mb-5" />
          <span className="inline-flex rounded-full border border-black/10 bg-brand-cream px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.16em] text-gray-700">Admin workspace</span>
        </div>

        {/* Card */}
        <div className="bg-white/70 rounded-3xl shadow-[0_18px_50px_rgb(63_68_32/0.06)] border border-white p-6 sm:p-8">
          <h1 className="text-2xl font-bold tracking-tight text-gray-900">Login to your account</h1>
          <p className="mt-2 mb-7 text-sm text-gray-600">Manage your partners, venues and approvals.</p>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
            {error && (
              <div className="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-4 py-3">
                {error}
              </div>
            )}

            {/* Email */}
            <div>
              <label htmlFor="email" className="label">Email address<span className="text-red-500">*</span></label>
              <input
                id="email"
                type="email"
                autoComplete="username"
                placeholder="Enter your email address"
                className={`input min-h-[52px] ${errors.email ? 'border-red-400 focus:ring-red-500/20 focus:border-red-400' : ''}`}
                {...register('email', {
                  required: 'Email is required',
                  pattern: { value: /^\S+@\S+$/i, message: 'Invalid email' },
                })}
              />
              {errors.email && (
                <p className="mt-1 text-xs text-red-500">{errors.email.message}</p>
              )}
            </div>

            {/* Password */}
            <div>
              <label htmlFor="password" className="label">Password<span className="text-red-500">*</span></label>
              <div className="relative">
                <input
                  id="password"
                  autoComplete="current-password"
                  type={showPassword ? 'text' : 'password'}
                  placeholder="Enter your password"
                  className={`input min-h-[52px] pr-12 ${errors.password ? 'border-red-400 focus:ring-red-500/20 focus:border-red-400' : ''}`}
                  {...register('password', { required: 'Password is required' })}
                />
                <button
                  type="button"
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                  aria-pressed={showPassword}
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
              {errors.password && (
                <p className="mt-1 text-xs text-red-500">{errors.password.message}</p>
              )}
            </div>

            <button
              type="submit"
              disabled={isSubmitting}
              className="btn-primary w-full min-h-[52px] text-base"
            >
              {isSubmitting ? 'Signing in...' : 'Login'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};
