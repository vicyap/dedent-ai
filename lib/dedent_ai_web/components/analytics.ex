defmodule DedentAiWeb.Analytics do
  @moduledoc """
  PostHog product analytics. Renders the posthog-js loader snippet in the root
  layout when `POSTHOG_PUBLIC_KEY` is set, otherwise no-ops so dev and tests
  don't ping production.
  """

  use Phoenix.Component

  @doc """
  Renders the PostHog client-side init snippet, or nothing if no key is
  configured.
  """
  def posthog_snippet(assigns) do
    config = Application.get_env(:dedent_ai, :posthog, [])

    assigns =
      assigns
      |> assign(:public_key, Keyword.get(config, :public_key))
      |> assign(:host, Keyword.get(config, :host, "https://us.i.posthog.com"))

    ~H"""
    <script :if={@public_key} phx-no-curly-interpolation>
      !function(t,e){var o,n,p,r;e.__SV||(window.posthog=e,e._i=[],e.init=function(i,s,a){function g(t,e){var o=e.split(".");2==o.length&&(t=t[o[0]],e=o[1]),t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)))}}(p=t.createElement("script")).type="text/javascript",p.crossOrigin="anonymous",p.async=!0,p.src=s.api_host.replace(".i.posthog.com","-assets.i.posthog.com")+"/static/array.js",(r=t.getElementsByTagName("script")[0]).parentNode.insertBefore(p,r);var u=e;for(void 0!==a?u=e[a]=[]:a="posthog",u.people=u.people||[],u.toString=function(t){var e="posthog";return"posthog"!==a&&(e+="."+a),t||(e+=" (stub)"),e},u.people.toString=function(){return u.toString(1)+".people (stub)"},o="init capture register register_once register_for_session unregister unregister_for_session getFeatureFlag getFeatureFlagPayload isFeatureEnabled reloadFeatureFlags updateEarlyAccessFeatureEnrollment getEarlyAccessFeatures on onFeatureFlags onSurveysLoaded onSessionId getSurveys getActiveMatchingSurveys renderSurvey canRenderSurvey canRenderSurveyAsync identify setPersonProperties group resetGroups setPersonPropertiesForFlags resetPersonPropertiesForFlags setGroupPropertiesForFlags resetGroupPropertiesForFlags reset opt_in_capturing opt_out_capturing has_opted_in_capturing has_opted_out_capturing clear_opt_in_out_capturing debug getPageViewId captureTraceFeedback captureTraceMetric".split(" "),n=0;n<o.length;n++)g(u,o[n]);e._i.push([i,s,a])},e.__SV=1)}(document,window.posthog||[]);
      posthog.init('<%= @public_key %>', { api_host: '<%= @host %>', defaults: '2026-01-30' });
    </script>
    """
  end
end
