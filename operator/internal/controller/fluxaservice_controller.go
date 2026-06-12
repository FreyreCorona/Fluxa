package controller

import (
	"bytes"
	"context"
	"embed"
	"fmt"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	networkingv1 "k8s.io/api/networking/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	fluxav1 "github.com/FreyreCorona/Fluxa/operator/api/v1"
)

const fluxaFinalizer = "fluxa.fluxa.io/finalizer"

//go:embed tierdata/tier_1/*.yaml
var tierFS embed.FS

// FluxaServiceReconciler reconciles a FluxaService object
type FluxaServiceReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// RBAC: permissions for the FluxaService CRD
// +kubebuilder:rbac:groups=fluxa.fluxa.io,resources=fluxaservices,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=fluxa.fluxa.io,resources=fluxaservices/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=fluxa.fluxa.io,resources=fluxaservices/finalizers,verbs=update

// RBAC: permissions for the resources the operator creates
// +kubebuilder:rbac:groups=core,resources=namespaces,verbs=get;list;watch;create;update;patch
// +kubebuilder:rbac:groups=core,resources=resourcequotas,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=limitranges,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=networkpolicies,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=ingresses,verbs=get;list;watch;create;update;patch;delete

// RBAC: events for status reporting
// +kubebuilder:rbac:groups=core,resources=events,verbs=create;patch

func (r *FluxaServiceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := logf.FromContext(ctx)
	log.Info("Reconciling FluxaService")

	var fs fluxav1.FluxaService
	if err := r.Get(ctx, req.NamespacedName, &fs); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	if !fs.DeletionTimestamp.IsZero() {
		return r.reconcileDelete(ctx, &fs)
	}

	if err := r.ensureFinalizer(ctx, &fs); err != nil {
		return ctrl.Result{}, err
	}

	nsName := fs.Name

	ns := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: nsName}}
	if err := r.Create(ctx, ns); err != nil {
		if !errors.IsAlreadyExists(err) {
			return r.failStatus(ctx, &fs, "NamespaceError", fmt.Sprintf("Failed to create namespace: %v", err))
		}
	} else {
		log.Info("Created namespace", "namespace", nsName)
	}

	if err := r.applyTierResources(ctx, fs.Spec.Tier, nsName); err != nil {
		return r.failStatus(ctx, &fs, "TierError", fmt.Sprintf("Failed to apply tier resources: %v", err))
	}

	dep := r.buildDeployment(&fs, nsName)
	if err := r.applyResource(ctx, dep); err != nil {
		return r.failStatus(ctx, &fs, "DeploymentError", fmt.Sprintf("Failed to apply Deployment: %v", err))
	}

	svc := r.buildService(&fs, nsName)
	if err := r.applyResource(ctx, svc); err != nil {
		return r.failStatus(ctx, &fs, "ServiceError", fmt.Sprintf("Failed to apply Service: %v", err))
	}

	if fs.Spec.Ingress != nil {
		ing := r.buildIngress(&fs, nsName)
		if err := r.applyResource(ctx, ing); err != nil {
			return r.failStatus(ctx, &fs, "IngressError", fmt.Sprintf("Failed to apply Ingress: %v", err))
		}
	}

	return r.readyStatus(ctx, &fs, nsName)
}

func (r *FluxaServiceReconciler) reconcileDelete(ctx context.Context, fs *fluxav1.FluxaService) (ctrl.Result, error) {
	log := logf.FromContext(ctx)
	log.Info("Deleting FluxaService")

	ns := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: fs.Name}}
	if err := r.Delete(ctx, ns); err != nil && !errors.IsNotFound(err) {
		return ctrl.Result{}, fmt.Errorf("failed to delete namespace: %w", err)
	}

	if err := r.removeFinalizer(ctx, fs); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func (r *FluxaServiceReconciler) ensureFinalizer(ctx context.Context, fs *fluxav1.FluxaService) error {
	if !containsString(fs.Finalizers, fluxaFinalizer) {
		fs.Finalizers = append(fs.Finalizers, fluxaFinalizer)
		return r.Update(ctx, fs)
	}
	return nil
}

func (r *FluxaServiceReconciler) removeFinalizer(ctx context.Context, fs *fluxav1.FluxaService) error {
	fs.Finalizers = removeString(fs.Finalizers, fluxaFinalizer)
	return r.Update(ctx, fs)
}

func (r *FluxaServiceReconciler) applyTierResources(ctx context.Context, tier, namespace string) error {
	dir := fmt.Sprintf("tierdata/%s", tier)
	entries, err := tierFS.ReadDir(dir)
	if err != nil {
		return fmt.Errorf("tier %s not supported", tier)
	}

	decoder := serializer.NewCodecFactory(r.Scheme).UniversalDeserializer()

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		data, err := tierFS.ReadFile(fmt.Sprintf("%s/%s", dir, entry.Name()))
		if err != nil {
			return fmt.Errorf("failed to read %s: %w", entry, err)
		}

		for _, doc := range bytes.Split(data, []byte("\n---\n")) {
			doc = bytes.TrimSpace(doc)
			if len(doc) == 0 {
				continue
			}

			obj := &unstructured.Unstructured{}
			_, _, err := decoder.Decode(doc, nil, obj)
			if err != nil {
				return fmt.Errorf("failed to decode %s: %w", entry, err)
			}

			obj.SetNamespace(namespace)
			if err := r.applyResource(ctx, obj); err != nil {
				return fmt.Errorf("failed to apply %s (%s): %w", entry, obj.GetKind(), err)
			}
		}
	}

	return nil
}

func (r *FluxaServiceReconciler) applyResource(ctx context.Context, obj client.Object) error {
	key := types.NamespacedName{Name: obj.GetName(), Namespace: obj.GetNamespace()}

	existing, ok := obj.DeepCopyObject().(client.Object)
	if !ok {
		return fmt.Errorf("object %T does not implement client.Object", obj)
	}

	if err := r.Get(ctx, key, existing); err != nil {
		if errors.IsNotFound(err) {
			return r.Create(ctx, obj)
		}
		return err
	}

	obj.SetResourceVersion(existing.GetResourceVersion())
	return r.Update(ctx, obj)
}

func (r *FluxaServiceReconciler) buildDeployment(fs *fluxav1.FluxaService, namespace string) *appsv1.Deployment {
	replicas := fs.Spec.Replicas
	labels := map[string]string{"app": fs.Name}

	containers := []corev1.Container{
		{
			Name:  fs.Name,
			Image: fs.Spec.Image,
			Ports: []corev1.ContainerPort{
				{ContainerPort: fs.Spec.Port},
			},
			Env: fs.Spec.Env,
		},
	}

	containers = append(containers, fs.Spec.Containers...)

	return &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fs.Name,
			Namespace: namespace,
			Labels:    labels,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: &replicas,
			Selector: &metav1.LabelSelector{MatchLabels: labels},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{Labels: labels},
				Spec: corev1.PodSpec{
					Containers: containers,
				},
			},
		},
	}
}

func (r *FluxaServiceReconciler) buildService(fs *fluxav1.FluxaService, namespace string) *corev1.Service {
	labels := map[string]string{"app": fs.Name}

	return &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fs.Name,
			Namespace: namespace,
			Labels:    labels,
		},
		Spec: corev1.ServiceSpec{
			Selector: labels,
			Ports: []corev1.ServicePort{
				{
					Port:       fs.Spec.Port,
					TargetPort: intstr.FromInt32(fs.Spec.Port),
					Protocol:   corev1.ProtocolTCP,
				},
			},
		},
	}
}

func (r *FluxaServiceReconciler) buildIngress(fs *fluxav1.FluxaService, namespace string) *networkingv1.Ingress {
	ing := fs.Spec.Ingress

	var rule networkingv1.IngressRule
	if ing.Host != "" {
		rule.Host = ing.Host
	}

	rule.IngressRuleValue = networkingv1.IngressRuleValue{
		HTTP: &networkingv1.HTTPIngressRuleValue{
			Paths: []networkingv1.HTTPIngressPath{
				{
					Path:     ing.Path,
					PathType: pathTypePtr(networkingv1.PathTypePrefix),
					Backend: networkingv1.IngressBackend{
						Service: &networkingv1.IngressServiceBackend{
							Name: fs.Name,
							Port: networkingv1.ServiceBackendPort{
								Number: ing.ServicePort,
							},
						},
					},
				},
			},
		},
	}

	return &networkingv1.Ingress{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fs.Name,
			Namespace: namespace,
		},
		Spec: networkingv1.IngressSpec{
			IngressClassName: stringPtr("traefik"),
			Rules:            []networkingv1.IngressRule{rule},
		},
	}
}

func (r *FluxaServiceReconciler) readyStatus(ctx context.Context, fs *fluxav1.FluxaService, nsName string) (ctrl.Result, error) {
	fs.Status.Namespace = nsName
	setCondition(&fs.Status, "Ready", metav1.ConditionTrue, "Ready", "All resources created")
	fs.Status.ObservedGeneration = fs.Generation

	if err := r.Status().Update(ctx, fs); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func (r *FluxaServiceReconciler) failStatus(ctx context.Context, fs *fluxav1.FluxaService, reason, message string) (ctrl.Result, error) {
	setCondition(&fs.Status, "Ready", metav1.ConditionFalse, reason, message)
	fs.Status.ObservedGeneration = fs.Generation

	if err := r.Status().Update(ctx, fs); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, fmt.Errorf("%s: %s", reason, message)
}

func (r *FluxaServiceReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&fluxav1.FluxaService{}).
		Owns(&appsv1.Deployment{}).
		Owns(&corev1.Service{}).
		Owns(&networkingv1.Ingress{}).
		Named("fluxaservice").
		Complete(r)
}

// --- helpers ---

func setCondition(status *fluxav1.FluxaServiceStatus, cType string, cStatus metav1.ConditionStatus, reason, message string) {
	now := metav1.Now()
	for i, c := range status.Conditions {
		if c.Type == cType {
			status.Conditions[i] = metav1.Condition{
				Type:               cType,
				Status:             cStatus,
				LastTransitionTime: now,
				Reason:             reason,
				Message:            message,
			}
			return
		}
	}
	status.Conditions = append(status.Conditions, metav1.Condition{
		Type:               cType,
		Status:             cStatus,
		LastTransitionTime: now,
		Reason:             reason,
		Message:            message,
	})
}

func containsString(slice []string, s string) bool {
	for _, item := range slice {
		if item == s {
			return true
		}
	}
	return false
}

func removeString(slice []string, s string) []string {
	var result []string
	for _, item := range slice {
		if item != s {
			result = append(result, item)
		}
	}
	return result
}

func pathTypePtr(p networkingv1.PathType) *networkingv1.PathType {
	return &p
}

func stringPtr(s string) *string {
	return &s
}
