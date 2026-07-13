import React from 'react';
import { Link } from 'react-router-dom';

interface BrandMarkProps {
  to?: string;
  className?: string;
  titleClassName?: string;
  subtitle?: string;
}

export const BrandMark: React.FC<BrandMarkProps> = ({
  to = '/',
  className,
  titleClassName,
  subtitle,
}) => {
  const content = (
    <>
      <span className="mf-brand-orb flex h-11 w-11 items-center justify-center rounded-2xl">
        <img
          src="/logo-memoryflow.png"
          alt="MemoryFlow"
          className="h-8 w-8 object-contain"
          loading="eager"
          decoding="async"
        />
      </span>
      <span className="flex min-w-0 flex-col">
        <span className={titleClassName ?? 'truncate text-base font-semibold tracking-[0.18em] text-white'}>
          MEMORYFLOW
        </span>
        {subtitle ? (
          <span className="truncate text-xs uppercase tracking-[0.28em] text-slate-400">{subtitle}</span>
        ) : null}
      </span>
    </>
  );

  return (
    <Link
      to={to}
      className={[
        'inline-flex items-center gap-3 rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-300/80',
        className,
      ]
        .filter(Boolean)
        .join(' ')}
    >
      {content}
    </Link>
  );
};
