import type { Clock } from '../context.js';
import type { Db } from '../db.js';

const DAY = 24 * 60 * 60 * 1000;

/**
 * How long things are kept once they are no longer needed. Proposed values,
 * pending legal review per region; see docs/DATA_LIFECYCLE_CONTRACT.md.
 */
export const retention = {
  /** Used or expired sign-in codes. */
  signInRequestsDays: 1,
  /** Sessions and sign-ins that ended (revoked or expired). */
  endedSessionsDays: 30,
  /** A device not used for this long signs in again. */
  idleSignInDays: 90,
  /** Photo uploads that were asked for but never sent. */
  unsentUploadsDays: 1,
  /** Rejected photo records (the files are deleted at once). */
  rejectedPhotosDays: 90,
  /** Security audit events (kind and time only). */
  auditEventsDays: 365,
  /** Call records (who, kind, times, outcome; never content). */
  callRecordsDays: 90,
  /** A call still marked live after this long lost both phones; it is closed. */
  staleCallHours: 6,
  /** Decided reports and appeals, with their notes. */
  decidedReportsDays: 730,
};

export async function runRetention(db: Db, clock: Clock): Promise<Record<string, number>> {
  const now = clock.now().getTime();
  const before = (days: number) => new Date(now - days * DAY);
  const count = async (sql: string, params: unknown[]) => (await db.query(sql, params)).length;
  return {
    signInRequests: await count(
      `DELETE FROM auth_requests WHERE (used_at IS NOT NULL OR expires_at < $2) AND expires_at < $1
       RETURNING 1`,
      [before(retention.signInRequestsDays), new Date(now)],
    ),
    // Sign-ins that ended (signed out, deleted, suspended) long ago.
    sessionFamilies: await count(
      'DELETE FROM session_families WHERE revoked_at IS NOT NULL AND revoked_at < $1 RETURNING 1',
      [before(retention.endedSessionsDays)],
    ),
    // A device unused for months: its sign-in ends and it signs in again.
    idleSignIns: await count(
      `DELETE FROM session_families f WHERE f.revoked_at IS NULL
         AND NOT EXISTS (SELECT 1 FROM sessions s WHERE s.family_id = f.id AND s.created_at >= $1)
       RETURNING 1`,
      [before(retention.idleSignInDays)],
    ),
    // Session records whose refresh token was rotated away long ago; the live one stays.
    rotatedSessions: await count(
      'DELETE FROM sessions WHERE refresh_used_at IS NOT NULL AND refresh_used_at < $1 RETURNING 1',
      [before(retention.endedSessionsDays)],
    ),
    unsentUploads: await count(
      "DELETE FROM media WHERE state = 'awaiting_upload' AND created_at < $1 RETURNING 1",
      [before(retention.unsentUploadsDays)],
    ),
    rejectedPhotos: await count(
      "DELETE FROM media WHERE state = 'rejected' AND created_at < $1 RETURNING 1",
      [before(retention.rejectedPhotosDays)],
    ),
    staleCalls: await count(
      `UPDATE calls SET state = CASE WHEN state = 'ringing' THEN 'missed' ELSE 'ended' END,
              ended_at = $2, end_reason = 'stale'
       WHERE state IN ('ringing','active') AND created_at < $1 RETURNING 1`,
      [new Date(now - retention.staleCallHours * 60 * 60 * 1000), new Date(now)],
    ),
    callRecords: await count('DELETE FROM calls WHERE created_at < $1 RETURNING 1', [
      before(retention.callRecordsDays),
    ]),
    auditEvents: await count('DELETE FROM audit_events WHERE created_at < $1 RETURNING 1', [
      before(retention.auditEventsDays),
    ]),
    reports: await count(
      "DELETE FROM reports WHERE state <> 'pending_review' AND decided_at < $1 RETURNING 1",
      [before(retention.decidedReportsDays)],
    ),
    appeals: await count("DELETE FROM appeals WHERE state <> 'open' AND decided_at < $1 RETURNING 1", [
      before(retention.decidedReportsDays),
    ]),
  };
}
