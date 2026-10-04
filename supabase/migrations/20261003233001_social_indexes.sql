create index social_reports_reporter on social_private.reports(reporter);
create index social_rooms_context_post on social_private.rooms(context_post);
create index social_rooms_requester_created on social_private.rooms(requester,created_at);
