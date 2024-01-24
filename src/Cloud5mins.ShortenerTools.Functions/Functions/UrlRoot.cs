using Cloud5mins.ShortenerTools.Core.Domain;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Threading;
using System.Threading.Tasks;

namespace Cloud5mins.ShortenerTools.Functions
{
    public class UrlRoot
    {
        private readonly ILogger _logger;
        private readonly ShortenerSettings _settings;

        public UrlRoot(ILoggerFactory loggerFactory, ShortenerSettings settings)
        {
            _logger = loggerFactory.CreateLogger<UrlRoot>();
            _settings = settings;
        }

        [Function("UrlRoot")]
        public async Task<HttpResponseData> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "/")]
            HttpRequestData req,
            ExecutionContext context)
        {
            string redirectUrl = "https://azure.com";
            redirectUrl = _settings.DefaultRootUrl ?? redirectUrl;
            var res = req.CreateResponse(HttpStatusCode.Redirect);
            res.Headers.Add("Location", redirectUrl);
            await Task.CompletedTask; // Added await keyword
            return res;
        }
    }
}
