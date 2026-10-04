// Standalone local practice: no public leaderboards, identity, or score uploads.
export class ScoreReporter {
  async submitMatchResult(_result:unknown):Promise<void>{}
  async submitTournamentResult(..._args:unknown[]):Promise<void>{}
}
