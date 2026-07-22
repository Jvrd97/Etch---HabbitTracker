// [review:need-review] PHASE-01/adhoc-lime-redesign
// summary: Thin rotating neon ring loader replacing the default border spinner

const SIZE_PX = { sm: 20, md: 36, lg: 52 } as const;
const STROKE_WIDTH = 2;
const ARC_FRACTION = 0.72;

export default function LoadingSpinner({ size = 'md' }: { size?: 'sm' | 'md' | 'lg' }) {
  const px = SIZE_PX[size];
  const radius = (px - STROKE_WIDTH) / 2;
  const circumference = 2 * Math.PI * radius;

  return (
    <div className="flex justify-center items-center p-6" role="status" aria-label="Loading">
      <svg
        width={px}
        height={px}
        viewBox={`0 0 ${px} ${px}`}
        className="animate-neon-spin drop-shadow-[0_0_6px_rgba(184,255,54,0.6)]"
      >
        <circle
          cx={px / 2}
          cy={px / 2}
          r={radius}
          fill="none"
          stroke="rgba(184,255,54,0.12)"
          strokeWidth={STROKE_WIDTH}
        />
        <circle
          cx={px / 2}
          cy={px / 2}
          r={radius}
          fill="none"
          stroke="#B8FF36"
          strokeWidth={STROKE_WIDTH}
          strokeLinecap="round"
          strokeDasharray={`${circumference * ARC_FRACTION} ${circumference}`}
        />
      </svg>
    </div>
  );
}
