type FormulaDisplayProps = {
  formula: string;
  name: string;
  details?: string;
};

export default function FormulaDisplay({
  formula,
  name,
  details,
}: FormulaDisplayProps) {
  return (
    <div className="rounded-2xl border border-white/10 bg-black/40 px-4 py-3 text-center shadow-[0_0_24px_rgba(124,131,255,0.2)]">
      <p className="text-xs uppercase tracking-[0.25em] text-white/50">{name}</p>
      <p className="mt-1 text-lg text-white/90 sm:text-xl">{formula}</p>
      {details ? <p className="mt-2 text-xs text-white/60">{details}</p> : null}
    </div>
  );
}
