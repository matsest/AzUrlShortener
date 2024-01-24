using Azure.Data.Tables;
using Azure.Core;
using Azure.Identity;
using System.Text.Json;

namespace Cloud5mins.ShortenerTools.Core.Domain
{
    public class StorageTableHelper
    {
        private Uri StorageUri { get; set; }

        public StorageTableHelper(Uri storageUri)
        {
            StorageUri = storageUri;
        }

        private TableServiceClient CreateTableServiceClient()
        {
            var credential = new DefaultAzureCredential();
            var tableServiceClient = new TableServiceClient(StorageUri, credential);
            return tableServiceClient;
        }

        private TableClient GetTable(string tableName)
        {
            var tableServiceClient = CreateTableServiceClient();
            var tableClient = tableServiceClient.GetTableClient(tableName);
            tableClient.CreateIfNotExists();
            return tableClient;
        }

        private TableClient GetUrlsTable()
        {
            TableClient table = GetTable("UrlsDetails");
            return table;
        }

        private TableClient GetStatsTable()
        {
            TableClient table = GetTable("ClickStats");
            return table;
        }

        public async Task<ShortUrlEntity> GetShortUrlEntity(ShortUrlEntity row)
        {
            ShortUrlEntity result = await GetUrlsTable().GetEntityAsync<ShortUrlEntity>(row.PartitionKey, row.RowKey);
            return result;
        }

        public async Task<List<ShortUrlEntity>> GetAllShortUrlEntities()
        {
            var tableClient = GetUrlsTable();
            var lstShortUrl = new List<ShortUrlEntity>();
            string filter = TableClient.CreateQueryFilter($"RowKey ne 'KEY'");

            await foreach (var entity in tableClient.QueryAsync<ShortUrlEntity>(filter))
            {
                lstShortUrl.Add(entity);
            }

            return lstShortUrl;
        }

        /// <summary>
        /// Returns the ShortUrlEntity of the <paramref name="vanity"/>
        /// </summary>
        /// <param name="vanity"></param>
        /// <returns>ShortUrlEntity</returns>
        public async Task<ShortUrlEntity> GetShortUrlEntityByVanity(string vanity)
        {
            var tableClient = GetUrlsTable();
            ShortUrlEntity? shortUrlEntity = null;
            string filter = Azure.Data.Tables.TableClient.CreateQueryFilter($"RowKey eq '{vanity}'");

            await foreach (var entity in tableClient.QueryAsync<ShortUrlEntity>(filter))
            {
                shortUrlEntity = entity;
                break;
            }

            return shortUrlEntity ?? new ShortUrlEntity();
        }
        public async Task SaveClickStatsEntity(ClickStatsEntity newStats)
        {
            var tableClient = GetStatsTable();
            await tableClient.UpsertEntityAsync(newStats);
        }

        public async Task<ShortUrlEntity> SaveShortUrlEntity(ShortUrlEntity newShortUrl)
        {
            var tableClient = GetUrlsTable();
            await tableClient.UpsertEntityAsync(newShortUrl);
            return newShortUrl;
        }

        public async Task<bool> IfShortUrlEntityExistByVanity(string vanity)
        {
            ShortUrlEntity shortUrlEntity = await GetShortUrlEntityByVanity(vanity);
            return (shortUrlEntity != null);
        }

        public async Task<bool> IfShortUrlEntityExist(ShortUrlEntity row)
        {
            ShortUrlEntity eShortUrl = await GetShortUrlEntity(row);
            return (eShortUrl != null);
        }
        public async Task<int> GetNextTableId()
        {
            var tableClient = GetUrlsTable();
            NextId? entity = null;

            try
            {
                var response = await tableClient.GetEntityAsync<NextId>("1", "KEY");
                entity = response.Value;
            }
            catch (Azure.RequestFailedException ex) when (ex.Status == 404)
            {
                entity = new NextId
                {
                    PartitionKey = "1",
                    RowKey = "KEY",
                    Id = 1024
                };
            }

            entity.Id++;

            await tableClient.UpsertEntityAsync(entity);

            return entity.Id;
        }


        public async Task<ShortUrlEntity> UpdateShortUrlEntity(ShortUrlEntity urlEntity)
        {
            ShortUrlEntity originalUrl = await GetShortUrlEntity(urlEntity);
            originalUrl.Url = urlEntity.Url;
            originalUrl.Title = urlEntity.Title;
            originalUrl.SchedulesPropertyRaw = JsonSerializer.Serialize<List<Schedule>>(urlEntity.Schedules);

            return await SaveShortUrlEntity(originalUrl);
        }


        public async Task<List<ClickStatsEntity>> GetAllStatsByVanity(string vanity)
        {
            var tableClient = GetStatsTable();
            var lstShortUrl = new List<ClickStatsEntity>();
            string? filter = string.IsNullOrEmpty(vanity) ? null : TableClient.CreateQueryFilter($"PartitionKey eq '{vanity}'");

            await foreach (var entity in tableClient.QueryAsync<ClickStatsEntity>(filter))
            {
                lstShortUrl.Add(entity);
            }

            return lstShortUrl;
        }


        public async Task<ShortUrlEntity> ArchiveShortUrlEntity(ShortUrlEntity urlEntity)
        {
            ShortUrlEntity originalUrl = await GetShortUrlEntity(urlEntity);
            originalUrl.IsArchived = true;

            return await SaveShortUrlEntity(originalUrl);
        }
    }
}