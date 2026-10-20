# SQLite / Drift 스키마

스키마 버전은 `AppDatabase.schemaVersion = 1`입니다. Drift가 `PRAGMA user_version`을 관리합니다. 신규 DB는 `onCreate`에서 생성하고, 향후 버전은 `onUpgrade`에 명시적인 트랜잭션 마이그레이션과 기존 데이터 유지 테스트를 추가해야 합니다. 현재는 존재하지 않는 버전 간 변환을 추측하지 않고 실패시킵니다. 실패한 DB를 자동 삭제하거나 재생성하지 않습니다.

| day_notes 열 | SQLite 저장 형식 | 의미 |
| --- | --- | --- |
| id | TEXT PRIMARY KEY | UUID v4, 삭제 후 재작성에도 유지 |
| date | TEXT NOT NULL | 로컬 달력 날짜 YYYY-MM-DD |
| content | TEXT NOT NULL | Unicode 자유 문서, 줄바꿈 보존 |
| created_at | INTEGER NOT NULL | UTC epoch 마이크로초 |
| updated_at | INTEGER NOT NULL | UTC epoch 마이크로초, 로컬 수정 시 단조 증가 |
| revision | INTEGER NOT NULL CHECK(revision > 0) | 로컬 수정마다 증가 |
| is_deleted | INTEGER NOT NULL DEFAULT 0 CHECK IN (0,1) | 빈 문서는 1로 저장 |

```sql
CREATE UNIQUE INDEX one_active_note_per_date
ON day_notes(date) WHERE is_deleted = 0;
```

동일 날짜의 활성 행은 하나만 허용합니다. 현재 로컬 Repository는 동일 행을 갱신하므로 삭제/재작성에도 UUID와 생성 시각이 유지됩니다. 변경 없는 저장은 revision을 올리지 않습니다. 새 날짜에서 빈 입력을 닫으면 불필요한 행을 만들지 않습니다.

설정은 `settings_entries(key TEXT PRIMARY KEY, value TEXT NOT NULL)`의 `window` 키에 JSON으로 저장합니다. x/y는 가상 화면의 물리 픽셀 좌표, width/height는 DIP입니다. DPI가 바뀌면 네이티브 어댑터가 물리 크기로 변환하고 복원 시 가장 가까운 모니터 작업 영역 안으로 조정합니다. 불투명도/글자 크기의 로컬 범위를 제한합니다.

실제 생성된 DDL은 [schema_v1.sql](schema_v1.sql)에 있습니다.

SQLite는 `foreign_keys=ON`, `busy_timeout=5000`, `journal_mode=WAL`, `synchronous=FULL`을 적용합니다. 메모 갱신은 트랜잭션으로 수행합니다. UI는 직렬화된 저장 완료를 기다리고 성공한 스냅샷만 저장됨으로 표시합니다. 디바운스 중 변경이나 쓰기 중 추가 입력은 후속 저장으로 처리합니다. 정상 앱 종료는 메모/설정 저장 완료 후 DB 연결을 닫고 네이티브 창을 종료합니다. 디스크 오류 시 입력을 메모리에 남기고 종료를 막습니다. 강제 프로세스 종료/전원 손실 이전의 미저장 입력까지 보장하지는 않습니다.

`lib/database/app_database.g.dart`는 Drift 생성 소스이며 함께 제공합니다. 스키마를 바꾸면 코드 생성 후 버전 증가, 마이그레이션 구현, 기존 버전 fixture 재실행이 필요합니다.
