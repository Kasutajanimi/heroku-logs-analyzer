The log file contains all requests to a server within a specific timeframe. Given the following endpoints:

GET /api/users/{user_id}/count_pending_messages
GET /api/users/{user_id}/get_messages
GET /api/users/{user_id}/get_friends_progress
GET /api/users/{user_id}/get_friends_score
POST /api/users/{user_id}
GET /api/users/{user_id}

Where {user_id} is the id of the user calling the backend.

The analysis of the log contains at the following:

For each of the URLs above:

- The number of times the URL was called.
- The mean (average), median and mode of the response time (connect time + service time).
- The "dyno" that responded the most.
